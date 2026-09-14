import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";

export interface StaffMember {
  id: string;
  tenant_id: string;
  email: string;
  name: string | null;
  role: "staff" | "admin";
}

interface AuthState {
  session: Session | null;
  staff: StaffMember | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthState>({
  session: null,
  staff: null,
  loading: true,
  signOut: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [staff, setStaff] = useState<StaffMember | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function loadStaff() {
      if (!session) {
        setStaff(null);
        setLoading(false);
        return;
      }

      // A signed-in user is not necessarily staff. Homeowners authenticate
      // against this same project, so being logged in proves nothing here —
      // the staff row is the authorization, and RLS returns zero rows for
      // anyone who isn't on the roster.
      const { data } = await supabase
        .from("staff")
        .select("id, tenant_id, email, name, role")
        .ilike("email", session.user.email ?? "")
        .maybeSingle();

      if (!cancelled) {
        setStaff((data as StaffMember) ?? null);
        setLoading(false);
      }
    }

    setLoading(true);
    loadStaff();
    return () => {
      cancelled = true;
    };
  }, [session]);

  async function signOut() {
    await supabase.auth.signOut();
    setStaff(null);
  }

  return (
    <AuthContext.Provider value={{ session, staff, loading, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
