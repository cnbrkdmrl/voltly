import SwiftUI

public enum VoltlyTab: Hashable {
    case dashboard
    case charges
    case insights
    case savings
    case settings
}

public struct VoltlyRootView: View {
    @State private var selectedTab: VoltlyTab = .dashboard
    @State private var showingAddCharge = false
    @State private var showingAuthUpsell = false
    @State private var dashboardRefreshID = UUID()
    @State private var environment: AppEnvironment
    @StateObject private var authSessionManager: AuthSessionManager
    @StateObject private var backupUpsellBannerCoordinator: BackupUpsellBannerCoordinator

    public init(
        environment: AppEnvironment,
        authSessionManager: AuthSessionManager
    ) {
        _environment = State(initialValue: environment)
        _authSessionManager = StateObject(wrappedValue: authSessionManager)
        _backupUpsellBannerCoordinator = StateObject(wrappedValue: BackupUpsellBannerCoordinator())
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardScreen(
                viewModel: DashboardViewModel(environment: environment),
                sessionState: authSessionManager.sessionState,
                backupBannerCoordinator: backupUpsellBannerCoordinator,
                onCreateAccountRequested: {
                    showingAuthUpsell = true
                },
                onAddChargeRequested: {
                    showingAddCharge = true
                }
            )
                .id(dashboardRefreshID)
                .tabItem { Label(L10n.dashboard, systemImage: "speedometer") }
                .tag(VoltlyTab.dashboard)

            ChargesListScreen(viewModel: ChargesListViewModel(environment: environment))
                .tabItem { Label(L10n.charges, systemImage: "list.bullet.rectangle") }
                .tag(VoltlyTab.charges)

            InsightsScreen(viewModel: InsightsViewModel(environment: environment))
                .tabItem { Label(L10n.insights, systemImage: "chart.pie") }
                .tag(VoltlyTab.insights)

            SavingsScreen(viewModel: SavingsViewModel(environment: environment))
                .tabItem { Label(L10n.savings, systemImage: "banknote") }
                .tag(VoltlyTab.savings)

            SettingsScreen(
                viewModel: SettingsViewModel(environment: environment),
                authSessionManager: authSessionManager
            )
                .tabItem { Label(L10n.settings, systemImage: "gear") }
                .tag(VoltlyTab.settings)
        }
        .tint(AppTheme.publicACColor)
        .environment(\.locale, appLocale)
        .safeAreaInset(edge: .top, alignment: .trailing) {
            if selectedTab == .dashboard {
                addChargeButton
                    .padding(.trailing, 16)
                    .padding(.top, 4)
            }
        }
        .safeAreaInset(edge: .top, alignment: .leading) {
            if selectedTab == .dashboard, authSessionManager.sessionState.isGuest {
                GuestModeBadge(
                    subtitle: "Veriler bu cihazda tutuluyor",
                    style: .compact
                )
                .padding(.leading, 16)
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showingAddCharge) {
            NavigationStack {
                AddChargeScreen(
                    viewModel: AddChargeViewModel(environment: environment),
                    onSaved: {
                        showingAddCharge = false
                        dashboardRefreshID = UUID()
                    },
                    onShowAnalysis: {
                        selectedTab = .insights
                    }
                )
            }
        }
        .sheet(isPresented: $showingAuthUpsell) {
            AuthUpsellScreen(sessionState: authSessionManager.sessionState) { action in
                handleAuthUpsellAction(action)
            }
        }
        .onAppear {
            environment.dailyInsightCoordinator.refreshCandidate()
        }
    }

    private var appLocale: Locale {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier
        return Locale(identifier: preferredIdentifier)
    }

    private var addChargeButton: some View {
        Button {
            showingAddCharge = true
        } label: {
            Label(L10n.addCharge, systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.publicDCColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(radius: 6)
        }
    }

    private func handleAuthUpsellAction(_ action: AuthUpsellAction) {
        switch action {
        case .email:
            authSessionManager.registerWithEmail(email: nil)
        case .apple, .google, .later:
            break
        }
        showingAuthUpsell = false
    }
}
