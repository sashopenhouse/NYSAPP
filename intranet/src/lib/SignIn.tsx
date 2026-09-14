import { useState, type FormEvent } from "react";
import { supabase } from "./supabase";

/// Email OTP, matching how the iOS app authenticates — same Supabase auth,
/// no separate password store for staff.
export function SignIn() {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function sendCode(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({ email });
    setBusy(false);
    if (error) setError(error.message);
    else setSent(true);
  }

  async function verify(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error } = await supabase.auth.verifyOtp({ email, token: code, type: "email" });
    setBusy(false);
    if (error) setError(error.message);
  }

  return (
    <div className="signin">
      <h1>New York Sash</h1>
      <p className="muted">Staff sign in</p>
      {error && <div className="banner">{error}</div>}
      <div className="card">
        {!sent ? (
          <form onSubmit={sendCode}>
            <label className="muted">Work email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoFocus
            />
            <button type="submit" disabled={busy} style={{ marginTop: 12, width: "100%" }}>
              {busy ? "Sending…" : "Send code"}
            </button>
          </form>
        ) : (
          <form onSubmit={verify}>
            <label className="muted">Code sent to {email}</label>
            <input value={code} onChange={(e) => setCode(e.target.value)} required autoFocus />
            <button type="submit" disabled={busy} style={{ marginTop: 12, width: "100%" }}>
              {busy ? "Verifying…" : "Sign in"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
