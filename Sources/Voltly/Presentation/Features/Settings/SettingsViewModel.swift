import Foundation

public enum AccountSyncStatus: String, Equatable {
    case idle
    case syncing
    case success
    case failed
}

public struct ProfileAchievementBadge: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let detail: String
    public let iconName: String
    public let isUnlocked: Bool
    public let progress: Double
    public let progressLabel: String
    public let category: AchievementBadgeCategory
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedCurrencyCode: String = AppConstants.defaultCurrencyCode
    @Published public var defaultElectricityPricePerKWh: String = ""
    @Published public var homeChargingPreferences: HomeChargingPreferences = .default
    @Published public var homeTariffInputs: [Int: String] = [:]
    @Published public var acChargePreferencePercent: Double = 50
    @Published public var dcChargePreferencePercent: Double = 50
    @Published public var distanceUnit: DistanceUnit = .km
    @Published public var fuelPricePerLiter: String = ""
    @Published public var iceConsumptionPer100Km: String = ""
    @Published public var usageMode: UsageMode = .balanced
    @Published public private(set) var exportFileURL: URL?
    @Published public private(set) var message: String?
    @Published public private(set) var accountSyncStatus: AccountSyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var achievementBadges: [ProfileAchievementBadge] = []
    @Published public private(set) var configuredGoals: [UserGoal] = []
    @Published public private(set) var suggestedGoalSet: SuggestedGoalSet?

    let environment: AppEnvironment
    private let sessionsCSVExportService: SessionsCSVExportServiceProtocol
    private let defaults: UserDefaults

    private enum Keys {
        static let lastSyncDate = "settings.account.lastSyncDate"
        static let acPreferencePercent = "settings.preferences.acChargePercent"
        static let dcPreferencePercent = "settings.preferences.dcChargePercent"
        static let distanceUnit = "settings.preferences.distanceUnit"
        static let achievementUnlockedIDs = "settings.achievements.unlockedIDs"
        static let achievementStoreInitialized = "settings.achievements.initialized"
        static let skippedGoalSuggestionMonth = "settings.goals.suggestion.skipped.month"
    }

    public init(
        environment: AppEnvironment,
        defaults: UserDefaults = .standard,
        sessionsCSVExportService: SessionsCSVExportServiceProtocol? = nil
    ) {
        self.environment = environment
        self.defaults = defaults
        self.sessionsCSVExportService = sessionsCSVExportService ?? SessionsCSVExportService(
            listSessionsUseCase: environment.listChargingSessionsUseCase,
            vehicleRepository: environment.vehicleRepository
        )
        load()
    }

    public let availableCurrencyCodes: [String] = ["TRY", "EUR", "USD"]

    public var bugReportMailURL: URL? {
        makeMailURL(
            subject: "Voltly Hata Bildirimi",
            prefilledBody: """
            Merhaba Voltly ekibi,

            Yaşadığım problem:



            Beklenen davranış:



            Uygulama sürümü: \(appVersionText)
            """
        )
    }

    public var suggestionMailURL: URL? {
        makeMailURL(
            subject: "Voltly Öneri",
            prefilledBody: """
            Merhaba Voltly ekibi,

            Önerim:



            Bu özelliğin faydası:



            Uygulama sürümü: \(appVersionText)
            """
        )
    }

    public var feedbackFormURL: URL? {
        URL(string: AppConstants.feedbackFormURLString)
    }

    public var privacyPolicyURL: URL? {
        URL(string: AppConstants.privacyPolicyURLString)
    }

    public var appStoreReviewURL: URL? {
        URL(string: AppConstants.appStoreReviewURLString)
    }

    public func load() {
        do {
            let settings = try environment.settingsRepository.getFuelBaseline()
            selectedCurrencyCode = availableCurrencyCodes.contains(settings.currencyCode) ? settings.currencyCode : AppConstants.defaultCurrencyCode
            defaultElectricityPricePerKWh = NumberFormatting.oneDecimal(settings.electricityPricePerKWh)
            homeChargingPreferences = HomeChargingPreferencesStore.load(defaults: defaults)
            syncHomeTariffInputsFromPreferences()
            fuelPricePerLiter = NumberFormatting.oneDecimal(settings.fuelPricePerLiter)
            iceConsumptionPer100Km = NumberFormatting.oneDecimal(settings.iceConsumptionLPer100Km)
            acChargePreferencePercent = defaults.object(forKey: Keys.acPreferencePercent) as? Double ?? 50
            dcChargePreferencePercent = defaults.object(forKey: Keys.dcPreferencePercent) as? Double ?? 50
            if let rawUnit = defaults.string(forKey: Keys.distanceUnit),
               let parsedUnit = DistanceUnit(rawValue: rawUnit) {
                distanceUnit = parsedUnit
            } else {
                distanceUnit = .km
            }
            usageMode = environment.usageModeStore.loadUsageMode()
            lastSyncDate = defaults.object(forKey: Keys.lastSyncDate) as? Date
            accountSyncStatus = lastSyncDate == nil ? .idle : .success
            exportFileURL = nil
            message = nil
            configuredGoals = try environment.goalRepository.fetchGoals()
            refreshGoalSuggestions()
            updateAchievementBadges()
        } catch {
            message = error.localizedDescription
            achievementBadges = []
            configuredGoals = []
        }
    }

    public func saveGoals(
        monthlySpendingTargetText: String,
        dcUsageRatioTargetText: String,
        monthlyEntryTargetText: String
    ) {
        do {
            let goals = try buildGoals(
                monthlySpendingTargetText: monthlySpendingTargetText,
                dcUsageRatioTargetText: dcUsageRatioTargetText,
                monthlyEntryTargetText: monthlyEntryTargetText
            )
            try environment.goalRepository.saveGoals(goals)
            configuredGoals = goals
            message = goals.isEmpty ? "Hedefler temizlendi." : "Hedefler kaydedildi."
            AppDataChangeNotifier.post(reason: .goalUpdate)
            Haptics.success()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }

    public func goalTargetText(for type: GoalType) -> String {
        guard let goal = configuredGoals.first(where: { $0.type == type }) else {
            return ""
        }

        switch type {
        case .monthlyChargeEntries:
            return "\(Int(goal.targetValue.rounded()))"
        case .monthlySpending, .dcUsageRatio:
            return NumberFormatting.oneDecimal(goal.targetValue)
        }
    }

    public var goalsSummaryText: String {
        guard !configuredGoals.isEmpty else {
            return "Hedef tanimla"
        }

        return configuredGoals
            .sorted { $0.type.rawValue < $1.type.rawValue }
            .map(\.type.shortTitleTR)
            .joined(separator: " • ")
    }

    public var goalsBadgeText: String? {
        if suggestedGoalSet != nil {
            return "Öneri var"
        }
        return nil
    }

    public func persistUsageMode() {
        environment.usageModeStore.saveUsageMode(usageMode)
        refreshGoalSuggestions()
        AppDataChangeNotifier.post(reason: .goalUpdate)
    }

    public func refreshGoalSuggestions(referenceDate: Date = .now) {
        do {
            guard let vehicle = try environment.vehicleRepository.fetchActiveVehicle() else {
                suggestedGoalSet = nil
                return
            }
            let monthKey = DateFormatter.monthKey.string(from: referenceDate)
            if defaults.string(forKey: Keys.skippedGoalSuggestionMonth) == monthKey {
                suggestedGoalSet = nil
                return
            }
            let sessions = try environment.chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            let report = environment.chargeInsightService.analyze(
                vehicle: vehicle,
                sessions: sessions,
                referenceDate: referenceDate
            )
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let savingsReport = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: sessions,
                preferences: baseline,
                referenceDate: referenceDate
            )

            suggestedGoalSet = environment.goalSuggestionEngine.suggest(
                input: GoalSuggestionInput(
                    usageMode: usageMode,
                    report: report,
                    savingsReport: savingsReport,
                    sessions: sessions,
                    referenceDate: referenceDate
                )
            )
        } catch {
            suggestedGoalSet = nil
        }
    }

    public func acceptSuggestedGoals() {
        guard let suggestion = suggestedGoalSet else { return }
        let goals = suggestion.goals.map { item in
            UserGoal(
                type: item.type,
                targetValue: item.targetValue,
                createdBy: .system,
                sourceReason: item.reason,
                isAccepted: true
            )
        }
        do {
            try environment.goalRepository.saveGoals(goals)
            configuredGoals = goals
            suggestedGoalSet = nil
            defaults.removeObject(forKey: Keys.skippedGoalSuggestionMonth)
            message = "Hedefler kaydedildi."
            AppDataChangeNotifier.post(reason: .goalUpdate)
        } catch {
            message = error.localizedDescription
        }
    }

    public func skipSuggestedGoals(referenceDate: Date = .now) {
        let monthKey = DateFormatter.monthKey.string(from: referenceDate)
        defaults.set(monthKey, forKey: Keys.skippedGoalSuggestionMonth)
        suggestedGoalSet = nil
    }

    public func suggestedGoalTargetText(for type: GoalType) -> String {
        guard let goal = suggestedGoalSet?.goals.first(where: { $0.type == type }) else {
            return ""
        }

        switch type {
        case .monthlyChargeEntries:
            return "\(Int(goal.targetValue.rounded()))"
        case .monthlySpending, .dcUsageRatio:
            return NumberFormatting.oneDecimal(goal.targetValue)
        }
    }

    public func save() {
        guard let electricityPrice = parseDecimal(defaultElectricityPricePerKWh),
              electricityPrice > 0 else {
            message = "Varsayilan elektrik fiyati gecersiz"
            Haptics.error()
            return
        }

        guard let fuelPrice = parseDecimal(fuelPricePerLiter),
              let consumption = parseDecimal(iceConsumptionPer100Km),
              fuelPrice > 0,
              consumption > 0 else {
            message = "Gecerli degerler girin"
            Haptics.error()
            return
        }

        do {
            try environment.settingsRepository.saveFuelBaseline(
                FuelBaselineSettings(
                    fuelPricePerLiter: fuelPrice,
                    iceConsumptionLPer100Km: consumption,
                    currencyCode: selectedCurrencyCode,
                    electricityPricePerKWh: electricityPrice
                )
            )
            persistLocalPreferences()
            message = "Kaydedildi"
            Haptics.success()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }

    public func saveChargingPreferences() {
        guard let electricityPrice = parseDecimal(defaultElectricityPricePerKWh),
              electricityPrice > 0 else {
            message = "Ev elektrik fiyatı geçersiz."
            Haptics.error()
            return
        }

        if let validationMessage = applyHomeTariffInputsToPreferences() {
            message = validationMessage
            Haptics.error()
            return
        }

        do {
            normalizeAndPersistHomeChargingPreferences()
            let current = try environment.settingsRepository.getFuelBaseline()
            try environment.settingsRepository.saveFuelBaseline(
                FuelBaselineSettings(
                    fuelPricePerLiter: current.fuelPricePerLiter,
                    iceConsumptionLPer100Km: current.iceConsumptionLPer100Km,
                    currencyCode: selectedCurrencyCode,
                    electricityPricePerKWh: electricityPrice
                )
            )
            persistLocalPreferences()
            message = "Şarj varsayılanları kaydedildi."
            Haptics.success()
        } catch {
            message = "Şarj varsayılanları kaydedilemedi: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    public var enabledHomeProfiles: [HomeChargingProfile] {
        homeChargingPreferences.enabledProfiles
    }

    public var secondHomeEnabled: Bool {
        homeChargingPreferences.profiles.first(where: { $0.id == 2 })?.isEnabled == true
    }

    public var thirdHomeEnabled: Bool {
        homeChargingPreferences.profiles.first(where: { $0.id == 3 })?.isEnabled == true
    }

    public var canShowThirdHomeOption: Bool {
        secondHomeEnabled
    }

    public func homeProfile(for profileID: Int) -> HomeChargingProfile? {
        homeChargingPreferences.profiles.first(where: { $0.id == profileID })
    }

    public func homeTariffText(for profileID: Int) -> String {
        homeTariffInputs[profileID, default: ""]
    }

    public func setHomeTariffText(_ text: String, profileID: Int) {
        homeTariffInputs[profileID] = text
    }

    public func setHomeProfileName(profileID: Int, name: String) {
        guard let index = homeChargingPreferences.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        homeChargingPreferences.profiles[index].name = name
    }

    public func setHomeProfileLocation(profileID: Int, location: String) {
        guard let index = homeChargingPreferences.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        homeChargingPreferences.profiles[index].location = location
    }

    public func setHomeProfileEnabled(profileID: Int, isEnabled: Bool) {
        guard let index = homeChargingPreferences.profiles.firstIndex(where: { $0.id == profileID }) else { return }

        if profileID == 1 {
            homeChargingPreferences.profiles[index].isEnabled = true
            return
        }

        if profileID == 3 && !secondHomeEnabled {
            return
        }

        homeChargingPreferences.profiles[index].isEnabled = isEnabled
        if profileID == 2, !isEnabled {
            if let thirdIndex = homeChargingPreferences.profiles.firstIndex(where: { $0.id == 3 }) {
                homeChargingPreferences.profiles[thirdIndex].isEnabled = false
            }
        }

        if !isEnabled || profileID == 2 {
            let enabledIDs = Set(homeChargingPreferences.enabledProfiles.map(\.id))
            if !enabledIDs.contains(homeChargingPreferences.defaultProfileID) {
                homeChargingPreferences.defaultProfileID = homeChargingPreferences.enabledProfiles.first?.id ?? 1
            }
        }
    }

    public func setDefaultHomeProfile(id: Int) {
        guard homeChargingPreferences.enabledProfiles.contains(where: { $0.id == id }) else { return }
        homeChargingPreferences.defaultProfileID = id
    }

    public func saveAppPreferences() {
        do {
            let current = try environment.settingsRepository.getFuelBaseline()
            try environment.settingsRepository.saveFuelBaseline(
                FuelBaselineSettings(
                    fuelPricePerLiter: current.fuelPricePerLiter,
                    iceConsumptionLPer100Km: current.iceConsumptionLPer100Km,
                    currencyCode: selectedCurrencyCode,
                    electricityPricePerKWh: current.electricityPricePerKWh
                )
            )
            persistLocalPreferences()
            message = "Uygulama tercihleri kaydedildi."
            Haptics.success()
        } catch {
            message = "Uygulama tercihleri kaydedilemedi: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    public func prepareCSVExport() {
        do {
            let fileURL = try sessionsCSVExportService.exportChargingSessionsCSV(to: nil)
            exportFileURL = fileURL
            message = "CSV dosyan hazır."
            Haptics.success()
        } catch let error as SessionCSVExportError {
            exportFileURL = nil
            message = error.localizedDescription
            Haptics.error()
        } catch {
            exportFileURL = nil
            message = "CSV hazırlanamadı: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    public var appName: String {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = bundleName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "Voltly"
    }

    public var appVersionText: String {
        "\(appVersion) (\(appBuildNumber))"
    }

    public var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    public var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var aboutSummary: String {
        "Voltly, elektrikli arac sarj kayitlarini takip etmen, analiz etmen ve aylik maliyet trendlerini izlemen icin tasarlandi."
    }

    public func syncAccountData(sessionState: SessionState) {
        guard sessionState.isAuthenticated else {
            accountSyncStatus = .idle
            message = AccountBackupCopy.signInRequiredMessage
            Haptics.error()
            return
        }

        accountSyncStatus = .syncing
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
                self.lastSyncDate = Date()
                self.defaults.set(self.lastSyncDate, forKey: Keys.lastSyncDate)
                self.accountSyncStatus = .success
                self.message = AccountBackupCopy.backupCompletedMessage
                Haptics.success()
            } catch {
                self.accountSyncStatus = .failed
                self.message = AccountBackupCopy.backupFailedMessage
                Haptics.error()
            }
        }
    }

    public func didSignIn(provider: AuthProvider) {
        message = "\(provider.titleTR) ile giris yapildi"
    }

    public func didSignOut() {
        accountSyncStatus = .idle
        lastSyncDate = nil
        defaults.removeObject(forKey: Keys.lastSyncDate)
        message = "Cikis yapildi"
    }

    public func didRequestDeleteAccount() {
        message = "Hesap silme yakinda eklenecek"
    }

    public func persistLocalPreferences() {
        defaults.set(acChargePreferencePercent, forKey: Keys.acPreferencePercent)
        defaults.set(dcChargePreferencePercent, forKey: Keys.dcPreferencePercent)
        defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
    }

    public func resetAllChargingData() {
        do {
            let sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: nil)
            guard !sessions.isEmpty else {
                message = "Silinecek şarj kaydı bulunamadı."
                Haptics.error()
                return
            }

            for session in sessions {
                try environment.deleteChargingSessionUseCase.execute(id: session.id)
            }

            exportFileURL = nil
            updateAchievementBadges()
            message = "Tüm şarj kayıtları silindi."
            Haptics.success()
        } catch {
            message = "Veriler sıfırlanamadı: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func buildGoals(
        monthlySpendingTargetText: String,
        dcUsageRatioTargetText: String,
        monthlyEntryTargetText: String
    ) throws -> [UserGoal] {
        var goals: [UserGoal] = []
        let existingByType = Dictionary(uniqueKeysWithValues: configuredGoals.map { ($0.type, $0) })

        if !monthlySpendingTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let value = parseDecimal(monthlySpendingTargetText), value > 0 else {
                throw GoalValidationError.invalidMonthlySpending
            }

            goals.append(makeGoal(type: .monthlySpending, targetValue: value, existing: existingByType[.monthlySpending]))
        }

        if !dcUsageRatioTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let value = parseDecimal(dcUsageRatioTargetText), value > 0, value <= 100 else {
                throw GoalValidationError.invalidDCRatio
            }

            goals.append(makeGoal(type: .dcUsageRatio, targetValue: value, existing: existingByType[.dcUsageRatio]))
        }

        if !monthlyEntryTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let value = parseDecimal(monthlyEntryTargetText), value > 0 else {
                throw GoalValidationError.invalidMonthlyEntryCount
            }

            goals.append(
                makeGoal(
                    type: .monthlyChargeEntries,
                    targetValue: value.rounded(),
                    existing: existingByType[.monthlyChargeEntries]
                )
            )
        }

        return goals.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    private func makeGoal(type: GoalType, targetValue: Double, existing: UserGoal?) -> UserGoal {
        UserGoal(
            id: existing?.id ?? UUID(),
            type: type,
            targetValue: targetValue,
            isActive: true,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
    }

    private func normalizeAndPersistHomeChargingPreferences() {
        HomeChargingPreferencesStore.save(homeChargingPreferences, defaults: defaults)
        homeChargingPreferences = HomeChargingPreferencesStore.load(defaults: defaults)
        syncHomeTariffInputsFromPreferences()
    }

    private func syncHomeTariffInputsFromPreferences() {
        var inputs: [Int: String] = [:]
        for profile in homeChargingPreferences.profiles {
            if let tariff = profile.tariffPricePerKWh, tariff > 0 {
                inputs[profile.id] = NumberFormatting.oneDecimal(tariff)
            } else {
                inputs[profile.id] = ""
            }
        }
        homeTariffInputs = inputs
    }

    private func applyHomeTariffInputsToPreferences() -> String? {
        for index in homeChargingPreferences.profiles.indices {
            let profileID = homeChargingPreferences.profiles[index].id
            let raw = homeTariffInputs[profileID, default: ""]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if raw.isEmpty {
                homeChargingPreferences.profiles[index].tariffPricePerKWh = nil
                continue
            }

            guard let value = parseDecimal(raw), value > 0 else {
                return "\(profileID). ev için elektrik fiyatı geçersiz."
            }

            homeChargingPreferences.profiles[index].tariffPricePerKWh = value
        }
        return nil
    }

    private func makeMailURL(subject: String, prefilledBody: String) -> URL? {
        let recipient = AppConstants.feedbackEmailAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? AppConstants.feedbackEmailAddress
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = prefilledBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prefilledBody
        return URL(string: "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    private func updateAchievementBadges() {
        do {
            let sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: nil)
            let previousUnlockedIDs = Set(defaults.stringArray(forKey: Keys.achievementUnlockedIDs) ?? [])
            let evaluation = environment.achievementService.evaluate(
                sessions: sessions,
                previouslyUnlockedIDs: previousUnlockedIDs
            )

            achievementBadges = evaluation.badges.map { badge in
                ProfileAchievementBadge(
                    id: badge.id,
                    title: badge.title,
                    subtitle: badge.subtitle,
                    detail: badge.detail,
                    iconName: badge.iconName,
                    isUnlocked: badge.isUnlocked,
                    progress: badge.progress,
                    progressLabel: badge.progressLabel,
                    category: badge.category
                )
            }

            let hasInitializedStore = defaults.bool(forKey: Keys.achievementStoreInitialized)
            defaults.set(Array(evaluation.unlockedBadgeIDs).sorted(), forKey: Keys.achievementUnlockedIDs)
            defaults.set(true, forKey: Keys.achievementStoreInitialized)

            if hasInitializedStore,
               let firstNewBadge = evaluation.newlyUnlockedBadges.first {
                message = "Rozet kazanıldı: \(firstNewBadge.title)"
                Haptics.success()
            }
        } catch {
            achievementBadges = []
        }
    }

    private enum GoalValidationError: LocalizedError {
        case invalidMonthlySpending
        case invalidDCRatio
        case invalidMonthlyEntryCount

        var errorDescription: String? {
            switch self {
            case .invalidMonthlySpending:
                return "Aylik harcama hedefi gecersiz."
            case .invalidDCRatio:
                return "DC kullanim orani 0 ile 100 arasinda olmali."
            case .invalidMonthlyEntryCount:
                return "Aylik kayit hedefi gecersiz."
            }
        }
    }

}
