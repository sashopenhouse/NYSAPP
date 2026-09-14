// Polls MarketSharp for changed inquiries and appends project_events rows.
//
// Why a poller and not a webhook receiver, unlike connecteam-webhook:
// MarketSharp has no outbound webhooks. Verified against their public Swagger
// specs (restapi.marketsharpm.com/swagger/docs/1.0 and /2.0) — 426 operations
// across both versions, and the only webhook-shaped path is POST /edge/webhook,
// an INBOUND receiver for their Edge partner integration. There is no
// subscription registration, no event catalogue, no delivery target config.
// So change detection is polling, full stop.
//
// This runs ALONGSIDE connecteam-webhook rather than replacing it, so the two
// can be compared on real jobs before committing to either. project_events
// already records `source`, and migration 0016 adds the idempotency needed to
// let both write safely.
//
// Deploy:  supabase functions deploy marketsharp-poll
// Schedule: invoke on a cron (see POLL_INTERVAL_NOTE below).

import { createClient } from "jsr:@supabase/supabase-js@2";

const API_BASE = "https://restapi.marketsharpm.com";
const API_VERSION = "2.0";

// POLL_INTERVAL_NOTE: MarketSharp documents no rate limit — no 429 responses
// are defined on any of the 426 operations, and there is no published
// guidance. Five minutes is a deliberately conservative default that still
// satisfies the build plan's "within minutes" bar for a live tracker. Confirm
// the real limit with MarketSharp support before tightening it.
const LOOKBACK_MINUTES = Number(Deno.env.get("MARKETSHARP_LOOKBACK_MINUTES") ?? "15");

const API_KEY = Deno.env.get("MARKETSHARP_API_KEY");
const API_SECRET = Deno.env.get("MARKETSHARP_API_SECRET");
const COMPANY_ID = Deno.env.get("MARKETSHARP_COMPANY_ID");
const EMPLOYEE_ID = Deno.env.get("MARKETSHARP_EMPLOYEE_ID");

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// MarketSharp's own vocabulary differs from the seven-stage pipeline in
// BUILD_PLAN.md. Mapping is explicit and total: an unmapped status is
// skipped and logged rather than guessed at, because inventing a stage
// would move a homeowner's timeline for the wrong reason.
const STATUS_TO_STAGE: Record<string, string> = {
  "measure": "measure",
  "measured": "measure",
  "sold": "order_placed",
  "order placed": "order_placed",
  "ordered": "order_placed",
  "permit": "permit",
  "permit applied": "permit",
  "permit approved": "permit",
  "scheduled": "install_scheduled",
  "install scheduled": "install_scheduled",
  "in production": "install_scheduled",
  "installing": "install",
  "install": "install",
  "in progress": "install",
  "punch list": "punch_list",
  "service": "punch_list",
  "complete": "final",
  "completed": "final",
  "final": "final",
  "closed": "final",
};

interface TokenResponse {
  access_token: string;
  expires_in: number;
}

async function getToken(): Promise<string> {
  // Application auth (apikey + apisecret + empoid), which works across
  // companies, rather than employee auth tied to one person's login.
  const form = new URLSearchParams({
    grant_type: "password",
    apikey: API_KEY!,
    apisecret: API_SECRET!,
    companyId: COMPANY_ID!,
  });
  if (EMPLOYEE_ID) form.set("empoid", EMPLOYEE_ID);

  const response = await fetch(`${API_BASE}/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: form,
  });

  if (!response.ok) {
    throw new Error(`token request failed: ${response.status} ${await response.text()}`);
  }

  const body = (await response.json()) as TokenResponse;
  return body.access_token;
}

interface Inquiry {
  id?: string | number;
  inquiryId?: string | number;
  contactId?: string | number;
  inquiryStatus?: string;
  lastModifiedDateTime?: string;
}

/// MarketSharp reports timestamps in the COMPANY's local timezone, not UTC.
/// Formatting the window boundary in that zone rather than sending a UTC
/// instant is what keeps the cursor from silently skipping or re-reading
/// records across a DST transition.
function formatInUpstreamZone(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(date);

  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "00";
  return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}:${get("second")}`;
}

async function fetchChangedInquiries(
  token: string,
  since: Date,
  until: Date,
  timeZone: string,
): Promise<Inquiry[]> {
  const results: Inquiry[] = [];
  let pageNumber = 1;

  // Paginate rather than assuming one page. The documented default is 1000
  // rows, which a busy window could exceed.
  for (;;) {
    const response = await fetch(
      `${API_BASE}/companies/${COMPANY_ID}/inquiries/filter?api-version=${API_VERSION}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          start_modified_datetime: formatInUpstreamZone(since, timeZone),
          end_modified_datetime: formatInUpstreamZone(until, timeZone),
          pageNumber,
          rowsPerPage: 500,
        }),
      },
    );

    if (response.status === 429) {
      // No documented rate limit means no documented backoff either, so
      // honour Retry-After when offered and give up this run otherwise.
      // Partial progress is fine: the cursor only advances on success.
      const retryAfter = response.headers.get("retry-after");
      throw new Error(`rate limited by MarketSharp${retryAfter ? `, retry after ${retryAfter}s` : ""}`);
    }

    if (!response.ok) {
      throw new Error(`inquiries/filter failed: ${response.status} ${await response.text()}`);
    }

    const body = await response.json();
    const page: Inquiry[] = Array.isArray(body) ? body : body?.items ?? body?.results ?? [];
    results.push(...page);

    if (page.length < 500) break;
    pageNumber += 1;
    if (pageNumber > 20) break; // hard stop; a window this large means something is wrong
  }

  return results;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (!API_KEY || !API_SECRET || !COMPANY_ID) {
    return Response.json(
      { ok: false, reason: "MARKETSHARP_API_KEY, MARKETSHARP_API_SECRET and MARKETSHARP_COMPANY_ID must be set" },
      { status: 200 },
    );
  }

  const { data: tenant } = await supabase.from("tenants").select("id").limit(1).maybeSingle();
  if (!tenant) return Response.json({ ok: false, reason: "no tenant" });

  const { data: cursor } = await supabase
    .from("sync_cursors")
    .select("last_synced_at, upstream_timezone")
    .eq("tenant_id", tenant.id)
    .eq("source", "marketsharp")
    .maybeSingle();

  const timeZone = cursor?.upstream_timezone ?? "America/New_York";
  const until = new Date();
  // Overlap the previous window deliberately. Re-reading is free now that
  // migration 0016 makes inserts idempotent, and it closes the gap where a
  // record modified during the last run would otherwise be missed.
  const since = cursor?.last_synced_at
    ? new Date(new Date(cursor.last_synced_at).getTime() - 60_000)
    : new Date(Date.now() - LOOKBACK_MINUTES * 60_000);

  let inserted = 0;
  let skippedUnmapped = 0;
  let unlinked = 0;

  try {
    const token = await getToken();
    const inquiries = await fetchChangedInquiries(token, since, until, timeZone);

    for (const inquiry of inquiries) {
      const externalId = String(inquiry.inquiryId ?? inquiry.id ?? "");
      const status = (inquiry.inquiryStatus ?? "").trim().toLowerCase();
      if (!externalId || !status) continue;

      const stage = STATUS_TO_STAGE[status];
      if (!stage) {
        // Unmapped status: skip and count, never guess. Guessing would move
        // a homeowner's timeline for a reason nobody intended.
        skippedUnmapped += 1;
        continue;
      }

      const { data: contact } = await supabase
        .from("contacts")
        .select("id, tenant_id")
        .or(`marketsharp_inquiry_id.eq.${externalId},marketsharp_contact_id.eq.${String(inquiry.contactId ?? "")}`)
        .maybeSingle();

      if (!contact) {
        // No mapped homeowner yet. Expected during rollout — contacts are
        // linked to MarketSharp ids at deal-close time.
        unlinked += 1;
        continue;
      }

      const { data: project } = await supabase
        .from("projects")
        .select("id")
        .eq("contact_id", contact.id)
        .maybeSingle();

      if (!project) {
        unlinked += 1;
        continue;
      }

      const occurredAt = inquiry.lastModifiedDateTime
        ? new Date(inquiry.lastModifiedDateTime).toISOString()
        : new Date().toISOString();

      // Idempotent by (source, external_id, stage) — migration 0016. This is
      // what makes re-polling safe, and it is load-bearing: MarketSharp
      // returns the CURRENT time as lastModifiedDateTime for records with no
      // modification date, so those resurface on every single poll forever.
      const { error: insertError } = await supabase.from("project_events").insert({
        tenant_id: contact.tenant_id,
        project_id: project.id,
        stage,
        occurred_at: occurredAt,
        source: "marketsharp",
        external_id: externalId,
        raw_payload: inquiry,
      });

      if (!insertError) {
        inserted += 1;
        await supabase.from("projects").update({ stage }).eq("id", project.id);
      } else if (!insertError.message.includes("duplicate key")) {
        throw insertError;
      }
    }

    await supabase.from("sync_cursors").upsert(
      {
        tenant_id: tenant.id,
        source: "marketsharp",
        last_synced_at: until.toISOString(),
        upstream_timezone: timeZone,
        last_run_at: new Date().toISOString(),
        last_error: null,
        consecutive_failures: 0,
      },
      { onConflict: "tenant_id,source" },
    );

    return Response.json({ ok: true, seen: inquiries.length, inserted, skippedUnmapped, unlinked });
  } catch (error) {
    // Leave last_synced_at alone on failure so the next run retries the same
    // window rather than skipping past whatever went wrong.
    const message = error instanceof Error ? error.message : String(error);
    const { data: existing } = await supabase
      .from("sync_cursors")
      .select("consecutive_failures")
      .eq("tenant_id", tenant.id)
      .eq("source", "marketsharp")
      .maybeSingle();

    await supabase.from("sync_cursors").upsert(
      {
        tenant_id: tenant.id,
        source: "marketsharp",
        upstream_timezone: timeZone,
        last_run_at: new Date().toISOString(),
        last_error: message,
        consecutive_failures: (existing?.consecutive_failures ?? 0) + 1,
      },
      { onConflict: "tenant_id,source" },
    );

    return Response.json({ ok: false, reason: message }, { status: 200 });
  }
});
