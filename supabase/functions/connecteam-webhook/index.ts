// Receives Connecteam form-submission webhooks and appends a project_events row.
//
// Why forms, not the Jobs API: Connecteam has no job-level webhook — only
// Jobs polling. Forms (and Tasks) do push in real time. Stage tracking is
// modeled as a "status" manager field on a per-job Connecteam form, so a
// stage change arrives here as `manager_field_updated` (or `form_submission`
// for the first fill). See docs/sync-validation.md for the full writeup.
//
// Deploy: supabase functions deploy connecteam-webhook
// Register this function's URL as the webhook target in Connecteam
// (Settings -> API -> Webhooks, or via the webhook-registration API).

import { createClient } from "jsr:@supabase/supabase-js@2";

const STAGE_MAP: Record<string, string> = {
  "Measure": "measure",
  "Order Placed": "order_placed",
  "Permit": "permit",
  "Install Scheduled": "install_scheduled",
  "Install": "install",
  "Punch List": "punch_list",
  "Final": "final",
};

interface ConnecteamManagerField {
  managerFieldId: string;
  managerFieldType: string;
  value?: unknown;
}

interface ConnecteamWebhookPayload {
  requestId: string;
  activityType: string;
  eventType: "form_submission" | "form_submission_edited" | "manager_field_updated";
  eventTimestamp: number;
  data: {
    formId: string;
    formSubmissionId: string;
    submittingUserId: number;
    jobId?: string;
    managerFields?: ConnecteamManagerField[];
  };
}

const WEBHOOK_SECRET = Deno.env.get("CONNECTEAM_WEBHOOK_SECRET");
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function extractStage(payload: ConnecteamWebhookPayload): string | null {
  const statusField = payload.data.managerFields?.find(
    (f) => f.managerFieldType === "status",
  );
  if (!statusField || typeof statusField.value !== "string") return null;
  return STAGE_MAP[statusField.value] ?? null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (WEBHOOK_SECRET) {
    const signature = req.headers.get("x-connecteam-signature");
    if (signature !== WEBHOOK_SECRET) {
      return new Response("unauthorized", { status: 401 });
    }
  }

  const payload = (await req.json()) as ConnecteamWebhookPayload;

  if (payload.activityType !== "forms" || payload.eventType === "form_submission_edited") {
    return new Response("ignored", { status: 200 });
  }

  const jobId = payload.data.jobId;
  if (!jobId) {
    return new Response("no jobId on payload, cannot link project", { status: 200 });
  }

  const stage = extractStage(payload);
  if (!stage) {
    return new Response("no status field change in payload", { status: 200 });
  }

  const { data: contact, error: contactError } = await supabase
    .from("contacts")
    .select("id, tenant_id")
    .eq("connectteam_job_id", jobId)
    .maybeSingle();

  if (contactError || !contact) {
    return new Response(`no contact mapped to job ${jobId}`, { status: 200 });
  }

  const { data: project, error: projectError } = await supabase
    .from("projects")
    .select("id")
    .eq("contact_id", contact.id)
    .maybeSingle();

  if (projectError || !project) {
    return new Response(`no project for contact ${contact.id}`, { status: 200 });
  }

  const occurredAt = new Date(payload.eventTimestamp * 1000).toISOString();

  const { error: insertError } = await supabase.from("project_events").insert({
    tenant_id: contact.tenant_id,
    project_id: project.id,
    stage,
    occurred_at: occurredAt,
    source: "connecteam",
    raw_payload: payload,
  });

  if (insertError) {
    return new Response(`insert failed: ${insertError.message}`, { status: 500 });
  }

  await supabase.from("projects").update({ stage }).eq("id", project.id);

  return new Response("ok", { status: 200 });
});
