import SwiftUI

public struct LaunchRootView: View {
    @StateObject private var router: LaunchRouter
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
        _router = StateObject(wrappedValue: LaunchRouter(environment: environment))
    }

    public var body: some View {
        Group {
            switch router.route {
            case .splash:
                LaunchSplashScreen()
            case .onboarding:
                OnboardingFlowView { mode in
                    router.completeOnboarding(mode: mode)
                }
            case .authUpsell:
                AuthUpsellScreen(sessionState: router.authSessionManager.sessionState) { action in
                    router.completeAuthUpsell(action: action)
                }
            case .vehicleSetup:
                NavigationStack {
                    FirstVehicleSetupScreen(
                        viewModel: FirstVehicleSetupViewModel(environment: environment),
                        onCompletion: {
                            router.completeVehicleSetup()
                        }
                    )
                }
            case .home:
                VoltlyRootView(
                    environment: environment,
                    authSessionManager: router.authSessionManager
                )
            }
        }
        .onAppear {
            router.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                router.refreshRoute()
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}

public struct LaunchSplashScreen: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            BrandLogoView(size: 72, cornerRadius: 18)
            Text(L10n.appTitle)
                .font(.title2.weight(.semibold))
            ProgressView()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
struct LaunchRootView_Previews: PreviewProvider {
    static var previews: some View {
        let environment = try! AppEnvironment.live(inMemory: true)
        LaunchRootView(environment: environment)
    }
}
#endif
