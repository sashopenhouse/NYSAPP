// Answers a homeowner's project-status question, or stays silent.
//
// Scope is deliberately narrow (see BUILD_PLAN.md): this agent answers ONLY
// from the project's own rows in Supabase — stage, install window, crew,
// documents, payment schedule. It has no general knowledge of pricing,
// warranty terms, or anything it might otherwise guess at, because it is
// speaking unsupervised to a customer about a real contract.
//
// Two hard rules, enforced structurally rather than by prompt alone:
//
//  1. Facts come from the database, never the model. The project context is
//     fetched here and passed in; the model's job is phrasing, not recall.
//  2. When the answer isn't in that context, it does not reply at all. It
//     records a handoff and the office picks the thread up. A wrong install
//     date is worse than a slow human one.
//
// Siro note: Siro's recorded sales conversations may later inform TONE (how
// a good NYS rep phrases things) via the system prompt. They must never
// become a source of FACTS, and no Siro transcript content is sent to a
// homeowner — those are recorded third-party conversations carrying their
// own consent constraints.
//
// Deploy: supabase functions deploy chat-agent

import { createClient } from "jsr:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const MODEL = "claude-sonnet-5";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const STAGE_LABELS: Record<string, string> = {
  measure: "Measure",
  order_placed: "Order Placed",
  permit: "Permit",
  install_scheduled: "Install Scheduled",
  install: "Install",
  punch_list: "Punch List",
  final: "Final",
};

interface ProjectContext {
  stage: string | null;
  installWindowStart: string | null;
  installWindowEnd: string | null;
  crew: string[];
  documents: { title: string | null; kind: string }[];
  payments: { label: string; amountCents: number; dueOn: string | null; paid: boolean }[];
  timeline: { stage: string; occurredAt: string }[];
}

async function loadProjectContext(projectId: string): Promise<ProjectContext | null> {
  const { data: project } = await supabase
    .from("projects")
    .select("stage, crew_ids, install_window_start, install_window_end")
    .eq("id", projectId)
    .maybeSingle();

  if (!project) return null;

  const [{ data: documents }, { data: payments }, { data: events }] = await Promise.all([
    supabase.from("documents").select("title, kind").eq("project_id", projectId),
    supabase
      .from("payments")
      .select("label, amount_cents, due_on, paid_at")
      .eq("project_id", projectId)
      .order("sequence", { ascending: true }),
    supabase
      .from("project_events")
      .select("stage, occurred_at")
      .eq("project_id", projectId)
      .order("occurred_at", { ascending: true }),
  ]);

  return {
    stage: project.stage ?? null,
    installWindowStart: project.install_window_start ?? null,
    installWindowEnd: project.install_window_end ?? null,
    crew: project.crew_ids ?? [],
    documents: (documents ?? []).map((d) => ({ title: d.title, kind: d.kind })),
    payments: (payments ?? []).map((p) => ({
      label: p.label,
      amountCents: p.amount_cents,
      dueOn: p.due_on,
      paid: p.paid_at !== null,
    })),
    timeline: (events ?? []).map((e) => ({ stage: e.stage, occurredAt: e.occurred_at })),
  };
}

function renderContext(ctx: ProjectContext): string {
  const money = (cents: number) => "$" + (cents / 100).toFixed(2);
  const lines: string[] = [];

  lines.push("Current stage: " + (ctx.stage ? STAGE_LABELS[ctx.stage] ?? ctx.stage : "unknown"));

  if (ctx.installWindowStart && ctx.installWindowEnd) {
    lines.push("Install window: " + ctx.installWindowStart + " to " + ctx.installWindowEnd);
  } else {
    lines.push("Install window: not yet scheduled");
  }

  lines.push(
    ctx.crew.length
      ? "Crew assigned: " + ctx.crew.join(", ")
      : "Crew assigned: not yet assigned",
  );

  lines.push(
    ctx.documents.length
      ? "Documents available in the app: " +
        ctx.documents.map((d) => d.title ?? d.kind).join(", ")
      : "Documents available in the app: none yet",
  );

  if (ctx.payments.length) {
    lines.push("Payment schedule:");
    for (const p of ctx.payments) {
      const status = p.paid ? "paid" : p.dueOn ? "due " + p.dueOn : "no due date set";
      lines.push("  - " + p.label + ": " + money(p.amountCents) + " (" + status + ")");
    }
  } else {
    lines.push("Payment schedule: none on file");
  }

  if (ctx.timeline.length) {
    lines.push("Completed stages:");
    for (const e of ctx.timeline) {
      lines.push("  - " + (STAGE_LABELS[e.stage] ?? e.stage) + " on " + e.occurredAt);
    }
  }

  return lines.join("\n");
}

const SYSTEM_PROMPT = [
  "You answer a homeowner's questions about the status of their own remodeling project, inside the New York Sash app. New York Sash is a home remodeling company in Whitesboro, NY.",
  "",
  "You will be given a PROJECT CONTEXT block containing everything known about this customer's project. That block is your ONLY source of facts.",
  "",
  "Rules:",
  "- Answer ONLY using facts present in the PROJECT CONTEXT. Never infer, estimate, or recall anything from outside it.",
  "- If the answer is not fully contained in the PROJECT CONTEXT, do not answer. Hand off to the office instead.",
  "- Never discuss pricing beyond the payment schedule shown, never interpret warranty or contract terms, never promise a date that is not in the context, and never speculate about delays or their causes.",
  "- If the customer is upset, wants to change or cancel work, raises a complaint or a quality problem, or asks anything involving money beyond reading the schedule back, hand off. Do not attempt to resolve it.",
  "- Keep replies to 1-3 short sentences, warm and plain. No emoji, no exclamation marks, no sales pitch.",
  "- Refer to \"our office\" or \"your project manager\". Do not describe yourself as an AI or an assistant.",
  "",
  "Respond with a JSON object and nothing else:",
  '{"handoff": true|false, "reply": "your reply, or empty string when handoff is true", "reason": "short internal note when handing off"}',
  "",
  "Set handoff to true whenever you are not fully certain. A slow human answer is better than a confident wrong one.",
].join("\n");

interface AgentDecision {
  handoff: boolean;
  reply: string;
  reason?: string;
}

async function askModel(question: string, ctx: ProjectContext): Promise<AgentDecision> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 400,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content:
            "PROJECT CONTEXT:\n" + renderContext(ctx) +
            "\n\nCUSTOMER QUESTION:\n" + question,
        },
      ],
    }),
  });

  if (!response.ok) {
    return { handoff: true, reply: "", reason: "model call failed: " + response.status };
  }

  const body = await response.json();
  const text = body?.content?.[0]?.text ?? "";

  try {
    const parsed = JSON.parse(text) as AgentDecision;
    // A malformed or empty reply becomes a handoff, never silence and never
    // a half-formed message to the customer.
    if (typeof parsed.handoff !== "boolean") throw new Error("missing handoff");
    if (!parsed.handoff && !parsed.reply?.trim()) throw new Error("empty reply without handoff");
    return parsed;
  } catch (error) {
    return { handoff: true, reply: "", reason: "unparseable model output: " + error };
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (!ANTHROPIC_API_KEY) {
    return Response.json({ handled: false, reason: "no api key configured" });
  }

  const { messageId } = await req.json();
  if (!messageId) {
    return new Response("messageId required", { status: 400 });
  }

  // Load the triggering message. Service role, but scoped to the single row
  // we were handed — the agent never browses the messages table.
  const { data: message } = await supabase
    .from("messages")
    .select("id, project_id, tenant_id, sender, body")
    .eq("id", messageId)
    .maybeSingle();

  if (!message || message.sender !== "customer") {
    return Response.json({ handled: false, reason: "not a customer message" });
  }

  const ctx = await loadProjectContext(message.project_id);
  if (!ctx) {
    return Response.json({ handled: false, reason: "no project context" });
  }

  const decision = await askModel(message.body, ctx);

  if (decision.handoff) {
    // Silence is the correct outcome: the thread stays unanswered and the
    // office sees it exactly as they would any other incoming message.
    await supabase.from("agent_handoffs").insert({
      tenant_id: message.tenant_id,
      project_id: message.project_id,
      message_id: message.id,
      reason: decision.reason ?? "model declined to answer",
    });

    return Response.json({ handled: false, reason: decision.reason });
  }

  await supabase.from("messages").insert({
    tenant_id: message.tenant_id,
    project_id: message.project_id,
    sender: "office",
    body: decision.reply,
    authored_by_agent: true,
    in_reply_to: message.id,
  });

  return Response.json({ handled: true });
});
