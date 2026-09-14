import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

if (!url || !key) {
  throw new Error(
    "Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY. Copy .env.example to .env.local.",
  );
}

// Same Supabase project as the iOS app, on purpose: approving a photo here
// updates the row NYSApp already reads, so there is no sync layer and no
// drift between two databases we own. Access is separated by RLS (staff
// policies in migration 0015), not by pointing at a different database.
export const supabase = createClient(url, key);
