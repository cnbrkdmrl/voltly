import Foundation
import Combine

public enum LaunchRoute: Hashable {
    case splash
    case onboarding
    case authUpsell
    case vehicleSetup
    case home
}

public enum LaunchAccessMode: String, Hashable, CaseIterable {
    case authenticated
    case guest
}

public enum AuthUpsellAction: Hashable {
    case apple
    case google
    case email
    case later
}

public struct LaunchState: Equatable {
    public var hasCompletedOnboarding: Bool
    public var hasCreatedVehicle: Bool
    public var isAuthenticated: Bool
    public var isGuestMode: Bool

    public init(
        hasCompletedOnboarding: Bool,
        hasCreatedVehicle: Bool,
        isAuthenticated: Bool,
        isGuestMode: Bool
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasCreatedVehicle = hasCreatedVehicle
        self.isAuthenticated = isAuthenticated
        self.isGuestMode = isGuestMode
    }
}

public final class LaunchStateStore {
    private enum Keys {
        static let hasCompletedOnboarding = "launch.hasCompletedOnboarding"
        static let hasCreatedVehicle = "launch.hasCreatedVehicle"
        static let isAuthenticated = "launch.isAuthenticated"
        static let isGuestMode = "launch.isGuestMode"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> LaunchState {
        LaunchState(
            hasCompletedOnboarding: defaults.bool(forKey: Keys.hasCompletedOnboarding),
            hasCreatedVehicle: defaults.bool(forKey: Keys.hasCreatedVehicle),
            isAuthenticated: defaults.bool(forKey: Keys.isAuthenticated),
            isGuestMode: defaults.bool(forKey: Keys.isGuestMode)
        )
    }

    public func save(_ state: LaunchState) {
        defaults.set(state.hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        defaults.set(state.hasCreatedVehicle, forKey: Keys.hasCreatedVehicle)
        defaults.set(state.isAuthenticated, forKey: Keys.isAuthenticated)
        defaults.set(state.isGuestMode, forKey: Keys.isGuestMode)
    }
}

@MainActor
public final class LaunchRouter: ObservableObject {
    private enum CleanupKeys {
        static let demoSessionsPurged = "launch.cleanup.demo_sessions_purged_v1"
    }

    @Published public private(set) var route: LaunchRoute = .splash
    @Published public private(set) var state: LaunchState

    private let environment: AppEnvironment
    private let stateStore: LaunchStateStore
    public let authSessionManager: AuthSessionManager
    private var hasStarted = false
    private let minimumSplashDurationNanoseconds: UInt64 = 700_000_000

    public init(
        environment: AppEnvironment,
        stateStore: LaunchStateStore = LaunchStateStore(),
        authSessionManager: AuthSessionManager? = nil
    ) {
        self.environment = environment
        self.stateStore = stateStore
        self.authSessionManager = authSessionManager ?? AuthSessionManager()
        self.state = stateStore.load()
        bootstrapAuthSessionState()
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            await environment.unplugReminderScheduler.purgeLegacyReminders()
            purgePersistedQuickStartDemoSessionsIfNeeded()
            try? await Task.sleep(nanoseconds: minimumSplashDurationNanoseconds)
            refreshRoute()
        }
    }

    public func refreshRoute() {
        syncLegacyAuthFlagsFromSessionState()
        syncVehicleState()
        route = makeRoute(for: state)
    }

    public func completeOnboarding(mode: LaunchAccessMode) {
        environment.analytics.track(.onboardingCompleted)
        state.hasCompletedOnboarding = true
        switch mode {
        case .authenticated:
            authSessionManager.signOut()
        case .guest:
            authSessionManager.continueAsGuest()
        }
        syncLegacyAuthFlagsFromSessionState()
        persist()
        refreshRoute()
    }

    public func completeAuthUpsell(action: AuthUpsellAction) {
        switch action {
        case .later:
            authSessionManager.continueAsGuest()
        case .apple:
            authSessionManager.signInWithApple()
        case .google:
            authSessionManager.signInWithGoogle()
        case .email:
            authSessionManager.registerWithEmail(email: nil)
        }
        syncLegacyAuthFlagsFromSessionState()
        persist()
        refreshRoute()
    }

    public func completeVehicleSetup() {
        state.hasCreatedVehicle = true
        persist()
        refreshRoute()
    }

    private func syncVehicleState() {
        do {
            let hasVehicle = try !environment.vehicleRepository.fetchVehicles().isEmpty
            state.hasCreatedVehicle = hasVehicle
            persist()
        } catch {
            // Repository okunamazsa mevcut durumu koru.
        }
    }

    private func makeRoute(for state: LaunchState) -> LaunchRoute {
        if !state.hasCompletedOnboarding {
            return .onboarding
        }
        if !state.isAuthenticated && !state.isGuestMode {
            return .authUpsell
        }
        if !state.hasCreatedVehicle {
            return .vehicleSetup
        }
        return .home
    }

    private func persist() {
        stateStore.save(state)
    }

    private func purgePersistedQuickStartDemoSessionsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: CleanupKeys.demoSessionsPurged) else { return }

        do {
            let sessions = try environment.chargingSessionRepository.fetchAll(vehicleID: nil)
            let demoSessions = sessions.filter { session in
                isQuickStartDemoSession(session)
            }

            for session in demoSessions {
                try environment.chargingSessionRepository.delete(sessionID: session.id)
            }

            defaults.set(true, forKey: CleanupKeys.demoSessionsPurged)
        } catch {
            // Okuma veya silme basarisiz olursa normal acilisi engelleme.
        }
    }

    private func isQuickStartDemoSession(_ session: ChargingSession) -> Bool {
        let normalizedNote = session.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedNote == "ornek demo kaydi" {
            return true
        }

        let normalizedBrand = session.stationBrand?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let normalizedLocation = session.locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let roundedPrice = Int(session.priceTotal.rounded())
        let roundedEnergy = Int((session.energyKWh ?? 0).rounded())
        let roundedDuration = session.durationMin ?? -1
        let roundedStartSOC = Int(session.socStart.rounded())
        let roundedEndSOC = Int(session.socEnd.rounded())

        let matchesLegacySample =
            session.chargeMethod == .publicDC &&
            normalizedBrand == "zes" &&
            (normalizedLocation == "kadikoy" || normalizedLocation == "kadikoy emaar") &&
            (
                (roundedPrice == 420 && roundedEnergy == 43 && roundedDuration == 31 && roundedStartSOC == 18 && roundedEndSOC == 82) ||
                (roundedPrice == 480 && roundedEnergy == 35 && roundedDuration == 42 && roundedStartSOC == 22 && roundedEndSOC == 78)
            )

        return matchesLegacySample
    }

    private func bootstrapAuthSessionState() {
        if authSessionManager.sessionState.isSignedOut {
            if state.isGuestMode {
                authSessionManager.continueAsGuest()
            } else if state.isAuthenticated {
                let legacyUser = AuthUser(
                    id: "legacy-user",
                    email: nil,
                    displayName: nil,
                    provider: .email
                )
                authSessionManager.setAuthenticatedUser(legacyUser)
            }
        }
        syncLegacyAuthFlagsFromSessionState()
    }

    private func syncLegacyAuthFlagsFromSessionState() {
        switch authSessionManager.sessionState {
        case .guest:
            state.isAuthenticated = false
            state.isGuestMode = true
        case .authenticated:
            state.isAuthenticated = true
            state.isGuestMode = false
        case .signedOut:
            state.isAuthenticated = false
            state.isGuestMode = false
        }
    }
}
