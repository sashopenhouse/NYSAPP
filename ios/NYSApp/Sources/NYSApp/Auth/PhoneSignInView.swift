import SwiftUI

struct PhoneSignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var phoneDigits = ""
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
                phoneEntry
            case .codeSent(let phone):
                codeEntry(phone: phone)
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

    private var phoneEntry: some View {
        VStack(spacing: 12) {
            Text("Enter your phone number to sign in.")
                .font(NYSFont.body())
                .foregroundStyle(NYSColor.slateGray)
            TextField("(555) 555-5555", text: $phoneDigits)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .textFieldStyle(.nys)
            Button("Send code") {
                Task { await sendCode() }
            }
            .buttonStyle(.nysPrimary)
            .disabled(phoneDigits.filter(\.isNumber).count < 10)
        }
    }

    private func codeEntry(phone: String) -> some View {
        VStack(spacing: 12) {
            Text("Enter the code we texted you.")
                .font(NYSFont.body())
                .foregroundStyle(NYSColor.slateGray)
            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.nys)
            Button("Verify") {
                Task { await verifyCode(phone: phone) }
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
            try await auth.sendCode(toE164Phone: e164Phone)
        } catch {
            // The friendly copy below is intentionally generic for end users;
            // the underlying error (e.g. an SMS provider misconfiguration)
            // only shows up here, in the Xcode console, during development.
            print("sendCode failed: \(error)")
            errorMessage = "Couldn't send that code. Check the number and try again."
        }
    }

    private func verifyCode(phone: String) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.verifyCode(code, forE164Phone: phone)
        } catch {
            print("verifyCode failed: \(error)")
            errorMessage = "That code didn't match. Try again."
        }
    }

    /// US-only for now, matching the build plan's Central NY customer base.
    private var e164Phone: String {
        "+1" + phoneDigits.filter(\.isNumber)
    }
}
