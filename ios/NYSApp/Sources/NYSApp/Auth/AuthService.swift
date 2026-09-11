import Foundation
import Supabase

@Observable
final class AuthService {
    enum Status: Equatable {
        case signedOut
        case codeSent(email: String)
        case signedIn
    }

    private(set) var status: Status = .signedOut
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.client) {
        self.client = client
    }

    /// Email OTP, not phone: Twilio SMS requires either a paid account or a
    /// Twilio Verify service (trial-account SMS rejects Supabase's default
    /// OTP template — see docs/sync-validation.md). Email needs no
    /// third-party SMS provider, so it unblocks development now; phone can
    /// come back as an additional option once SMS is sorted.
    func sendCode(toEmail email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
        status = .codeSent(email: email)
    }

    func verifyCode(_ code: String, forEmail email: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .email)
        status = .signedIn
    }

    func signOut() async throws {
        try await client.auth.signOut()
        status = .signedOut
    }

    func restoreSession() async {
        if (try? await client.auth.session) != nil {
            status = .signedIn
        }
    }
}
