import SwiftUI

struct EmailSignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("New York Sash")
                .font(NYSFont.headline())
                .foregroundStyle(NYSColor.black)

            switch auth.status {
            case .signedOut:
                emailEntry
            case .codeSent(let email):
                codeEntry(email: email)
            case .signedIn:
                Text("Signed in.")
                    .font(NYSFont.body())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(NYSFont.body(13))
                    .foregroundStyle(NYSColor.actionRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(NYSColor.white)
        .disabled(isSubmitting)
    }

    private var emailEntry: some View {
        VStack(spacing: 12) {
            Text("Enter your email to sign in.")
                .font(NYSFont.body())
                .foregroundStyle(NYSColor.slateGray)
            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.nys)
            Button("Send code") {
                Task { await sendCode() }
            }
            .buttonStyle(.nysPrimary)
            .disabled(!isPlausibleEmail(email))
        }
    }

    private func codeEntry(email: String) -> some View {
        VStack(spacing: 12) {
            Text("Enter the code we emailed you.")
                .font(NYSFont.body())
                .foregroundStyle(NYSColor.slateGray)
            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.nys)
            Button("Verify") {
                Task { await verifyCode(email: email) }
            }
            .buttonStyle(.nysPrimary)
            .disabled(code.count < 6)
        }
    }

    private func sendCode() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.sendCode(toEmail: email)
        } catch {
            print("sendCode failed: \(error)")
            errorMessage = "Couldn't send that code. Check the email and try again."
        }
    }

    private func verifyCode(email: String) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.verifyCode(code, forEmail: email)
        } catch {
            print("verifyCode failed: \(error)")
            errorMessage = "That code didn't match. Try again."
        }
    }

    private func isPlausibleEmail(_ value: String) -> Bool {
        value.contains("@") && value.contains(".") && value.count >= 6
    }
}
