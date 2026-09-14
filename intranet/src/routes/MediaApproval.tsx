import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { useAuth } from "../lib/auth";

interface MediaRow {
  id: string;
  project_id: string;
  url: string;
  caption: string | null;
  source: string;
  approved_for_customer: boolean;
  created_at: string;
  projects: { contacts: { name: string | null } | null } | null;
}

/// The gate BUILD_PLAN.md describes: the crew photo feed is an internal
/// stream — dumpsters, rot behind old siding, half-finished walls — and a
/// homeowner should only ever see what someone here has promoted.
export function MediaApproval() {
  const { staff } = useAuth();
  const [rows, setRows] = useState<MediaRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showApproved, setShowApproved] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from("media")
      .select("id, project_id, url, caption, source, approved_for_customer, created_at, projects(contacts(name))")
      .eq("approved_for_customer", showApproved)
      .order("created_at", { ascending: false });

    setError(error?.message ?? null);
    setRows((data as unknown as MediaRow[]) ?? []);
    setLoading(false);
  }, [showApproved]);

  useEffect(() => {
    load();
  }, [load]);

  async function setApproval(id: string, approved: boolean) {
    setBusyId(id);
    const { error } = await supabase
      .from("media")
      .update({
        approved_for_customer: approved,
        approved_at: approved ? new Date().toISOString() : null,
        approved_by: approved ? staff?.id ?? null : null,
      })
      .eq("id", id);
    setBusyId(null);

    if (error) {
      setError(error.message);
      return;
    }
    // Drop it from the current list rather than refetching everything —
    // the row no longer belongs in whichever queue is being viewed.
    setRows((current) => current.filter((r) => r.id !== id));
  }

  return (
    <>
      <header>
        <h1>Photo approval</h1>
        <p>
          Crew photos are internal until someone here releases them. Approved photos appear in the
          homeowner&rsquo;s app immediately.
        </p>
      </header>

      {error && <div className="banner">{error}</div>}

      <div className="row" style={{ marginBottom: 16 }}>
        <button
          className={showApproved ? "secondary" : ""}
          onClick={() => setShowApproved(false)}
        >
          Pending
        </button>
        <button
          className={showApproved ? "" : "secondary"}
          onClick={() => setShowApproved(true)}
        >
          Released
        </button>
      </div>

      {loading ? (
        <div className="empty">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="empty">
          {showApproved ? "Nothing released yet." : "No photos waiting for review."}
        </div>
      ) : (
        <div className="grid">
          {rows.map((row) => (
            <div className="card" key={row.id}>
              <img className="thumb" src={row.url} alt={row.caption ?? "Project photo"} />
              <p style={{ margin: "10px 0 4px" }}>{row.caption || <em className="muted">No caption</em>}</p>
              <p className="muted">
                {row.projects?.contacts?.name ?? "Unknown customer"} ·{" "}
                {new Date(row.created_at).toLocaleDateString()} · {row.source}
              </p>
              <div className="row" style={{ marginTop: 10 }}>
                {showApproved ? (
                  <button
                    className="secondary"
                    disabled={busyId === row.id}
                    onClick={() => setApproval(row.id, false)}
                  >
                    {busyId === row.id ? "…" : "Unrelease"}
                  </button>
                ) : (
                  <button disabled={busyId === row.id} onClick={() => setApproval(row.id, true)}>
                    {busyId === row.id ? "…" : "Release to customer"}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
