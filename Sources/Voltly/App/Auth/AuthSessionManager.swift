import Foundation
import Combine

public protocol AuthSessionStoring {
    func load() -> SessionState
    func save(_ state: SessionState)
}

public final class UserDefaultsAuthSessionStore: AuthSessionStoring {
    private enum Keys {
        static let sessionState = "auth.session.state"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SessionState {
        guard let raw = defaults.data(forKey: Keys.sessionState),
              let state = try? decoder.decode(SessionState.self, from: raw) else {
            return .signedOut
        }
        return state
    }

    public func save(_ state: SessionState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: Keys.sessionState)
    }
}

@MainActor
public final class AuthSessionManager: ObservableObject {
    @Published public private(set) var sessionState: SessionState

    private let store: AuthSessionStoring

    public init(store: AuthSessionStoring = UserDefaultsAuthSessionStore()) {
        self.store = store
        self.sessionState = store.load()
    }

    public var currentUser: AuthUser? {
        sessionState.user
    }

    public func continueAsGuest() {
        Haptics.softImpact()
        setSession(.guest)
    }

    public func signInWithApple() {
        Haptics.success()
        setSession(.authenticated(makePlaceholderUser(provider: .apple)))
    }

    public func signInWithGoogle() {
        Haptics.success()
        setSession(.authenticated(makePlaceholderUser(provider: .google)))
    }

    public func registerWithEmail(email: String?) {
        let user = AuthUser(
            id: UUID().uuidString,
            email: email,
            displayName: nil,
            provider: .email
        )
        Haptics.success()
        setSession(.authenticated(user))
    }

    public func setAuthenticatedUser(_ user: AuthUser) {
        setSession(.authenticated(user))
    }

    public func signOut() {
        Haptics.softImpact()
        setSession(.signedOut)
    }

    public func applyExternalSessionState(_ state: SessionState) {
        // Firebase/Auth SDK callback'lerinden gelen state burada tek noktadan uygulanabilir.
        setSession(state)
    }

    private func setSession(_ newState: SessionState) {
        sessionState = newState
        store.save(newState)
    }

    private func makePlaceholderUser(provider: AuthProvider) -> AuthUser {
        AuthUser(
            id: UUID().uuidString,
            email: nil,
            displayName: nil,
            provider: provider
        )
    }
}
