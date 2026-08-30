import SwiftUI

public struct AuthSessionExampleView: View {
    @StateObject private var sessionManager = AuthSessionManager()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session: \(sessionDescription)")
                .font(.headline)

            Text("Provider: \(providerDescription)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Misafir") {
                    sessionManager.continueAsGuest()
                }
                Button("Apple") {
                    sessionManager.signInWithApple()
                }
                Button("Çıkış") {
                    sessionManager.signOut()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var sessionDescription: String {
        switch sessionManager.sessionState {
        case .guest:
            return "guest"
        case .signedOut:
            return "signedOut"
        case .authenticated:
            return "authenticated"
        }
    }

    private var providerDescription: String {
        sessionManager.currentUser?.provider.titleTR ?? "-"
    }
}

#if DEBUG
struct AuthSessionExampleView_Previews: PreviewProvider {
    static var previews: some View {
        AuthSessionExampleView()
    }
}
#endif
