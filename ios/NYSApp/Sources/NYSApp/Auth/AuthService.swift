import Foundation
import Supabase

@Observable
final class AuthService {
    enum Status: Equatable {
        case signedOut
        case codeSent(phone: String)
        case signedIn
    }

    private(set) var status: Status = .signedOut
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.client) {
        self.client = client
    }

    func sendCode(toE164Phone phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
        status = .codeSent(phone: phone)
    }

    func verifyCode(_ code: String, forE164Phone phone: String) async throws {
        try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
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
