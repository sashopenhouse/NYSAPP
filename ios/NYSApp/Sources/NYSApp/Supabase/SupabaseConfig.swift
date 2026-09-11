import Foundation

enum SupabaseConfig {
    // NYSAPP project, org "Sash Open House". Publishable key is safe to ship
    // client-side — it only grants what RLS policies allow.
    static let url = URL(string: "https://gbwhdieifcfrgzazpgas.supabase.co")!
    static let publishableKey = "sb_publishable_FRpQCxJMhvvnGJCofzqSEg_ISf6rHuG"
}
