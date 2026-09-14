import { NavLink, Route, Routes, Navigate } from "react-router-dom";
import { useAuth } from "./lib/auth";
import { SignIn } from "./lib/SignIn";
import { MediaApproval } from "./routes/MediaApproval";
import { Placeholder } from "./routes/Placeholder";

export default function App() {
  const { session, staff, loading, signOut } = useAuth();

  if (loading) return <div className="empty">Loading…</div>;
  if (!session) return <SignIn />;

  // Signed in but not on the staff roster. Homeowners authenticate against
  // this same Supabase project, so a valid session is not authorization —
  // and RLS would return empty tables anyway. Saying so plainly beats
  // showing a working-looking console with nothing in it.
  if (!staff) {
    return (
      <div className="signin">
        <h1>Not authorized</h1>
        <div className="card">
          <p>
            You are signed in as <strong>{session.user.email}</strong>, but that address is not on
            the New York Sash staff roster.
          </p>
          <p className="muted">Ask an administrator to add you, then sign in again.</p>
          <button className="secondary" onClick={signOut} style={{ marginTop: 12 }}>
            Sign out
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">New York Sash</div>
        <nav>
          <NavLink to="/media">Photo approval</NavLink>
          <NavLink to="/messages">Message queue</NavLink>
          {staff.role === "admin" && <NavLink to="/offers">Offers</NavLink>}
          <NavLink to="/library">Siro library</NavLink>
          {staff.role === "admin" && <NavLink to="/staff">Staff</NavLink>}
        </nav>
        <div className="footer">
          {staff.name ?? staff.email}
          <br />
          <span className="muted">{staff.role}</span>
          <br />
          <button className="secondary" onClick={signOut} style={{ marginTop: 10, padding: "6px 12px" }}>
            Sign out
          </button>
        </div>
      </aside>

      <main className="main">
        <Routes>
          <Route path="/" element={<Navigate to="/media" replace />} />
          <Route path="/media" element={<MediaApproval />} />
          <Route
            path="/messages"
            element={
              <Placeholder
                title="Message queue"
                note="Threads the chat agent handed off, plus anything a customer sent that nobody has answered. Not built yet."
              />
            }
          />
          <Route
            path="/offers"
            element={
              <Placeholder
                title="Offers"
                note="Create and publish the promos that appear in the app, targeted by customer stage. Not built yet — offers are still managed in SQL."
              />
            }
          />
          <Route
            path="/library"
            element={
              <Placeholder
                title="Siro library"
                note="Draft, review and publish knowledge base articles mined from Siro sales calls. Deferred by design — see BUILD_PLAN.md. Consent for reusing recorded calls must be confirmed before any transcript is processed."
              />
            }
          />
          <Route
            path="/staff"
            element={<Placeholder title="Staff" note="Add and remove staff access. Not built yet." />}
          />
        </Routes>
      </main>
    </div>
  );
}
