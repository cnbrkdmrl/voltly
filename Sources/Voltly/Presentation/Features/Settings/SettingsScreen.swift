import SwiftUI
#if os(iOS)
import MessageUI
#endif

public struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var authSessionManager: AuthSessionManager
    @State private var showingSignInOptions = false
    @State private var showingResetConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var safariDestination: SafariDestination?
    @State private var savedBannerMessage: String?
    @Environment(\.openURL) private var openURL

    #if os(iOS)
    @State private var mailDestination: MailDestination?
    #endif

    public init(
        viewModel: SettingsViewModel,
        authSessionManager: AuthSessionManager
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _authSessionManager = ObservedObject(wrappedValue: authSessionManager)
    }

    public var body: some View {
        NavigationStack {
            List {
                SettingsAccountSection(
                    sessionState: authSessionManager.sessionState,
                    syncStatus: viewModel.accountSyncStatus,
                    lastSyncDate: viewModel.lastSyncDate,
                    onSignIn: {
                        showingSignInOptions = true
                    },
                    onSync: {
                        viewModel.syncAccountData(sessionState: authSessionManager.sessionState)
                    },
                    onSignOut: {
                        authSessionManager.signOut()
                        viewModel.didSignOut()
                    },
                    onDeleteAccount: {
                        viewModel.didRequestDeleteAccount()
                    }
                )

                profileSection
                vehicleManagementSection
                operatorsSection
                chargingPreferencesSection
                usageModeSection
                goalsSection
                appPreferencesSection
                gasolineSection
                dataManagementSection
                privacySection
                aboutSection
                #if DEBUG
                debugSection
                #endif
                statusSection
            }
            .listStyle(settingsListStyle)
            .navigationTitle("Ayarlar")
            .onAppear {
                viewModel.load()
                viewModel.refreshGoalSuggestions()
            }
            .onChange(of: viewModel.usageMode) { _, _ in
                viewModel.persistUsageMode()
            }
            .onChange(of: viewModel.distanceUnit) { _, _ in
                viewModel.persistLocalPreferences()
            }
            .onChange(of: viewModel.message) { _, message in
                guard let message, isSuccessMessage(message) else { return }
                presentSavedBanner(message)
            }
            .confirmationDialog("Hesap oluştur", isPresented: $showingSignInOptions, titleVisibility: .visible) {
                Button("Email ile kayıt") {
                    authSessionManager.registerWithEmail(email: nil)
                    viewModel.didSignIn(provider: .email)
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Email adresiyle ücretsiz hesap oluşturabilirsin.")
            }
            .confirmationDialog("Verileri sıfırla", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Verileri sıfırla", role: .destructive) {
                    viewModel.resetAllChargingData()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm şarj kayıtlarını silmek istediğine emin misin?")
            }
            .sheet(item: $safariDestination) { destination in
                #if os(iOS)
                InAppSafariView(url: destination.url)
                    .ignoresSafeArea()
                #else
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("Bu bağlantıyı tarayıcıda açabilirsin:")
                            .font(.subheadline)
                        Text(destination.url.absoluteString)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        Button("Kapat") {
                            safariDestination = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                #endif
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                NavigationStack {
                    PrivacyPolicyView()
                }
            }
            #if os(iOS)
            .sheet(item: $mailDestination) { destination in
                FeedbackMailComposerView(draft: destination.draft) {
                    mailDestination = nil
                }
            }
            #endif
            .overlay(alignment: .top) {
                if let savedBannerMessage {
                    FloatingStatusBanner(title: savedBannerMessage)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var vehicleManagementSection: some View {
        Section("Araç Yönetimi") {
            NavigationLink {
                AraclarView(environment: viewModel.environment)
            } label: {
                Label("Araçları yönet", systemImage: "car")
            }
        }
    }

    private var profileSection: some View {
        Section("Profil") {
            NavigationLink {
                ProfileSettingsView(badges: viewModel.achievementBadges)
            } label: {
                Label("Başarı rozetleri", systemImage: "rosette")
            }
        }
    }

    private var operatorsSection: some View {
        Section("Şarj Operatörleri") {
            NavigationLink {
                OperatorsView(environment: viewModel.environment)
            } label: {
                Label("Operatörleri düzenle", systemImage: "bolt.fill")
            }
        }
    }

    private var chargingPreferencesSection: some View {
        Section("Şarj Varsayılanları") {
            NavigationLink {
                ChargingDefaultsView(viewModel: viewModel)
            } label: {
                Label("Şarj varsayılanlarını düzenle", systemImage: "house.fill")
            }
        }
    }

    private var appPreferencesSection: some View {
        Section("Uygulama Tercihleri") {
            Picker("Para birimi", selection: $viewModel.selectedCurrencyCode) {
                ForEach(viewModel.availableCurrencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Picker("Mesafe birimi", selection: $viewModel.distanceUnit) {
                ForEach(DistanceUnit.allCases, id: \.rawValue) { unit in
                    Text(unit.title).tag(unit)
                }
            }

            Button("Uygulama tercihlerini kaydet") {
                Haptics.softImpact()
                viewModel.saveAppPreferences()
            }
        }
    }

    private var goalsSection: some View {
        Section("Hedefler") {
            NavigationLink {
                GoalsSettingsView(viewModel: viewModel)
            } label: {
                LabeledContent {
                    HStack(spacing: 8) {
                        if let badge = viewModel.goalsBadgeText {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppTheme.publicACColor.opacity(0.14))
                                .foregroundStyle(AppTheme.publicACColor)
                                .clipShape(Capsule())
                        }
                        Text(viewModel.goalsSummaryText)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Hedeflerini duzenle", systemImage: "target")
                }
            }
        }
    }

    private var usageModeSection: some View {
        Section {
            ForEach(UsageMode.allCases) { mode in
                Button {
                    viewModel.usageMode = mode
                    Haptics.softImpact()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.iconName)
                            .foregroundStyle(viewModel.usageMode == mode ? AppTheme.publicACColor : .secondary)
                            .frame(width: 26, height: 26)
                            .background((viewModel.usageMode == mode ? AppTheme.publicACColor : Color.secondary).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.titleTR)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(mode.subtitleTR)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if viewModel.usageMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.publicACColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Kullanım Modu")
        } footer: {
            Text("Akıllı öneriler, hedef tahminleri ve şarj analizi bu moda göre kişiselleştirilir.")
        }
    }

    private var gasolineSection: some View {
        Section("Benzin Karşılaştırma") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Benzin fiyatı (TL/litre)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                TextField("Örn: 58", text: $viewModel.fuelPricePerLiter)
                    .voltlyDecimalKeyboard()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Benzin tüketimi (L/100 km)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                TextField("Örn: 6.5", text: $viewModel.iceConsumptionPer100Km)
                    .voltlyDecimalKeyboard()
            }

            Button("Kaydet") {
                Haptics.softImpact()
                viewModel.save()
            }
        }
    }

    private var dataManagementSection: some View {
        Section("Veri Yönetimi") {
            NavigationLink {
                BackupSettingsView(
                    viewModel: BackupSettingsViewModel(environment: viewModel.environment)
                )
            } label: {
                Label("Veri & Yedekleme", systemImage: "externaldrive")
            }

            Button("Verileri sıfırla", role: .destructive) {
                showingResetConfirmation = true
            }
        }
    }

    private var privacySection: some View {
        Section("Gizlilik") {
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Gizlilik politikası", systemImage: "lock.shield")
            }

            NavigationLink {
                DataUsageInfoView()
            } label: {
                Label("Veri kullanımı", systemImage: "lock.shield")
            }
        }
    }

    private var aboutSection: some View {
        Section("Hakkında") {
            LabeledContent("Uygulama adı", value: viewModel.appName)
            LabeledContent("Versiyon", value: viewModel.appVersion)
            LabeledContent("Build", value: viewModel.appBuildNumber)

            NavigationLink {
                AboutVoltlyView()
            } label: {
                Label("Uygulama hakkında", systemImage: "info.circle")
            }

            NavigationLink {
                QuickStartGuideView(environment: viewModel.environment)
            } label: {
                Label("Kullanım kılavuzu", systemImage: "book")
            }

            Menu {
                Button("Hata bildir") {
                    sendFeedback(kind: .bug)
                }
                Button("Öneri gönder") {
                    sendFeedback(kind: .suggestion)
                }
            } label: {
                Label("Geri bildirim gönder", systemImage: "person.circle")
            }

            // App Store değerlendirme linki — ID hazır olduğunda AppConstants.appStoreReviewURLString güncellenecek
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            NavigationLink {
                MigrationDebugView(
                    viewModel: MigrationDebugViewModel(
                        environment: viewModel.environment
                    )
                )
            } label: {
                Label("Migration Debug", systemImage: "arrow.triangle.branch")
            }

            NavigationLink {
                FeatureFlagsDebugView(
                    viewModel: FeatureFlagsDebugViewModel(
                        store: viewModel.environment.featureFlagStore,
                        checker: viewModel.environment.featureAccessChecker
                    )
                )
            } label: {
                Label("Feature Flags", systemImage: "switch.2")
            }
        }
    }
    #endif

    @ViewBuilder
    private var statusSection: some View {
        if let message = viewModel.message {
            Section {
                Text(message)
                    .foregroundStyle(messageColor(for: message))
            }
        }
    }

    private func sendFeedback(kind: FeedbackKind) {
        #if os(iOS)
        if MFMailComposeViewController.canSendMail() {
            mailDestination = MailDestination(
                draft: FeedbackMailComposerView.Draft(
                    recipients: [AppConstants.feedbackEmailAddress],
                    subject: kind.subject,
                    body: kind.body(version: viewModel.appVersionText)
                )
            )
            return
        }
        #endif

        switch kind {
        case .bug:
            if let url = viewModel.bugReportMailURL {
                openURL(url)
            }
        case .suggestion:
            if let url = viewModel.suggestionMailURL {
                openURL(url)
            }
        }
    }

    private func messageColor(for message: String) -> Color {
        let normalized = message.lowercased()
        if normalized.contains("kaydedildi") ||
            normalized.contains("hazir") ||
            normalized.contains("hazır") ||
            normalized.contains("yedeklendi") ||
            normalized.contains("giris yapildi") ||
            normalized.contains("cikis yapildi") ||
            normalized.contains("kazanildi") ||
            normalized.contains("kazanıldı") ||
            normalized.contains("silindi") {
            return .green
        }
        return .red
    }

    private var settingsListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .automatic
        #endif
    }

    private func isSuccessMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("kaydedildi") ||
            normalized.contains("hazir") ||
            normalized.contains("hazır") ||
            normalized.contains("yedeklendi") ||
            normalized.contains("giris yapildi") ||
            normalized.contains("cikis yapildi") ||
            normalized.contains("kazanildi") ||
            normalized.contains("kazanıldı") ||
            normalized.contains("silindi")
    }

    private func presentSavedBanner(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            savedBannerMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if savedBannerMessage == message {
                        savedBannerMessage = nil
                    }
                }
            }
        }
    }
}

private struct SafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(iOS)
private struct MailDestination: Identifiable {
    let id = UUID()
    let draft: FeedbackMailComposerView.Draft
}
#endif

private enum FeedbackKind {
    case bug
    case suggestion

    var subject: String {
        switch self {
        case .bug:
            return "Voltly Hata Bildirimi"
        case .suggestion:
            return "Voltly Öneri"
        }
    }

    func body(version: String) -> String {
        switch self {
        case .bug:
            return """
            Merhaba Voltly ekibi,

            Yaşadığım problem:



            Beklenen davranış:



            Uygulama sürümü: \(version)
            """
        case .suggestion:
            return """
            Merhaba Voltly ekibi,

            Önerim:



            Bu özelliğin faydası:



            Uygulama sürümü: \(version)
            """
        }
    }
}
