import Foundation

public struct AddChargeSaveSuccessPayload: Equatable {
    public let showFirstChargeCelebration: Bool
    public let sessionScore: ChargeSessionScoreReport?
    public let planFeedbackMessage: String?
    public let realtimeMetricsUpdate: ChargeMetricsRealtimeUpdate?
}

public enum AddChargeSaveResult: Equatable {
    case success(AddChargeSaveSuccessPayload)
    case failure
}

@MainActor
public final class AddChargeViewModel: ObservableObject {
    private enum PersistenceKeys {
        static let draft = "add_charge.draft"
        static let lastMethod = "add_charge.last.method"
        static let legacyLastTariff = "add_charge.last.tariff"
        static let lastTariffHome = "add_charge.last.tariff.home"
        static let lastTariffPublicAC = "add_charge.last.tariff.public_ac"
        static let lastTariffPublicDC = "add_charge.last.tariff.public_dc"
        static let lastHomeStation = "add_charge.last.home.station"
        static let lastHomeLocation = "add_charge.last.home.location"
        static let lastPublicStation = "add_charge.last.public.station"
        static let lastPublicLocation = "add_charge.last.public.location"
        static let favoriteOperators = "add_charge.favorite_operators"
        static let firstChargeCelebrationShown = "add_charge.first_charge.celebration_shown"
        static let skippedPlanRecommendationID = "add_charge.plan_recommendation.skipped.id"
        static let skippedPlanRecommendationAt = "add_charge.plan_recommendation.skipped.at"
    }

    private struct DraftPayload: Codable {
        let chargeMethodRaw: String
        let selectedHomeProfileID: Int
        let stationBrand: String
        let locationName: String
        let socStart: Double
        let socEnd: Double
        let totalPrice: String
        let tariffPricePerKWh: String
        let energyInput: String
        let durationMin: String
        let odometerKM: String
        let outsideTempC: String
        let notes: String
        let contextTagRawValues: [String]?
        let sessionDate: Date
        let includeSOCForPastDate: Bool
    }

    private enum ValidationLimits {
        static let maxEnergyKWh: Double = 500
        static let maxDurationMinutes: Double = 24 * 60
        static let maxOdometerKM: Double = 2_000_000
        static let minTemperatureC: Double = -50
        static let maxTemperatureC: Double = 70
        static let minACSpeedKW: Double = 2
        static let maxACSpeedKW: Double = 22
        static let minDCSpeedKW: Double = 10
        static let maxDCSpeedKW: Double = 250
    }

    private enum BehaviorConstants {
        static let skippedRecommendationSuppressionInterval: TimeInterval = 72 * 60 * 60
    }

    @Published public var chargeMethod: ChargeMethod = .home
    @Published public var selectedHomeProfileID: Int = 1
    @Published public var stationBrand: String = ""
    @Published public var locationName: String = ""
    @Published public var socStart: Double = 20
    @Published public var socEnd: Double = 80
    @Published public var totalPrice: String = ""
    @Published public var tariffPricePerKWh: String = ""
    @Published public var energyInput: String = ""
    @Published public var durationMin: String = ""
    @Published public var odometerKM: String = ""
    @Published public var outsideTempC: String = ""
    @Published public var notes: String = ""
    @Published public var selectedContextTags: [ChargeContextTag] = []
    @Published public var sessionDate: Date = .now
    @Published public var includeSOCForPastDate: Bool = false
    @Published public private(set) var favoriteOperatorNames: [String] = []
    @Published public private(set) var predictiveDefaults: PredictiveChargeDefaultsReport?
    @Published public private(set) var smartFavoriteStations: SmartFavoriteStationReport?
    @Published public private(set) var smartRepeatPlan: SmartRepeatChargePlan?
    @Published public private(set) var liveInsight: ChargeFormLiveInsight?
    @Published public private(set) var activePlan: MonthlyPlan?
    @Published public private(set) var planRecommendation: Recommendation?
    @Published public private(set) var smartRecommendationsEnabled = true
    @Published public private(set) var latestRealtimeMetricsUpdate: ChargeMetricsRealtimeUpdate?

    @Published public private(set) var activeVehicle: Vehicle?
    @Published public private(set) var availableHomeProfiles: [HomeChargingProfile] = []
    @Published public private(set) var message: String?

    private let environment: AppEnvironment
    private let editingSession: ChargingSession?
    private var sessionCurrencyCode: String = AppConstants.defaultCurrencyCode
    private var defaultElectricityTariffPerKWh: Double?
    private var recentStationLocationByBrand: [String: String] = [:]
    private var recentStationLocationsByBrand: [String: [String]] = [:]
    private var recentPublicLocations: [String] = []
    private var recentStationMethodByBrandLocation: [String: ChargeMethod] = [:]
    private var isApplyingAutofill = false
    private var locationWasAutoFilled = false
    private var homeProfileWasAutoFilled = false
    private var tariffWasAutoFilled = false
    private var hasRestoredDraft = false
    private var isDraftPersistenceEnabled = true
    private var latestRepeatTemplateSession: ChargingSession?
    private var historicalSessions: [ChargingSession] = []
    private var isSmartRecommendationsEnabled = true
    private var liveInsightTask: Task<Void, Never>?
    private let userDefaults: UserDefaults

    public init(
        environment: AppEnvironment,
        editingSession: ChargingSession? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.environment = environment
        self.editingSession = editingSession
        self.userDefaults = userDefaults
        refreshFeatureFlags()
        loadSettingsDefaults()
        loadHomeChargingPreferences()
        loadFavoriteOperators()
        loadActiveVehicle()
        if let editingSession {
            applyEditingValues(from: editingSession)
        } else {
            applyLastUsedDefaults()
            restoreDraftIfAvailable()
            if !hasRestoredDraft {
                applySelectedHomeProfileIfNeeded(onlyIfEmpty: false)
            }
        }
        loadRecentStationLocations()
        normalizeSOCSelectionState()
        applyTariffAutofillIfNeeded()
    }

    deinit {
        liveInsightTask?.cancel()
    }

    public var isEditing: Bool {
        editingSession != nil
    }

    public var canRepeatLastCharge: Bool {
        !isEditing && smartRecommendationsEnabled && smartRepeatPlan != nil
    }

    public var hasSmartRepeatRecommendation: Bool {
        smartRepeatPlan?.recommendation != nil
    }

    public var hasPredictiveQuickPresets: Bool {
        !(predictiveDefaults?.quickPresets.isEmpty ?? true)
    }

    public var hasSmartFavoriteStationSuggestions: Bool {
        !(smartFavoriteStations?.suggestions.isEmpty ?? true)
    }

    public var hasPlanRecommendation: Bool {
        activePlan != nil || planRecommendation != nil
    }

    public var planRecommendationHeadline: String {
        if let recommendation = planRecommendation {
            return recommendation.title
        }
        return activePlan?.title ?? "Bu ay planın"
    }

    public var planRecommendationDetail: String {
        if let recommendation = planRecommendation {
            return recommendation.detail
        }
        return activePlan?.summary ?? "Davranış planın hazır."
    }

    public var planAlignmentMessage: String {
        guard let recommendation = planRecommendation else {
            return "Bu seans aktif planını destekleyebilir."
        }

        if recommendation.suggestedChargeType == chargeMethod {
            return "Bu seçim plan hedefinle uyumlu görünüyor."
        }

        return "Bu seçim planla çelişebilir; maliyeti yukarı çekebilir."
    }

    public var operatorCatalog: [EVChargeOperator] {
        var operators = EVChargeOperator.turkiye
        let selected = canonicalOperatorName(stationBrand)
        guard chargeMethod != .home, !selected.isEmpty else { return operators }
        let selectedKey = Self.normalizeKey(selected)
        let alreadyIncluded = operators.contains { Self.normalizeKey($0.name) == selectedKey }
        if !alreadyIncluded {
            operators.insert(EVChargeOperator(name: selected), at: 0)
        }
        return operators
    }

    public var favoriteOperators: [EVChargeOperator] {
        let catalog = operatorCatalog
        return favoriteOperatorNames.map { favoriteName in
            if let matched = catalog.first(where: {
                Self.normalizeKey($0.name) == Self.normalizeKey(favoriteName)
            }) {
                return matched
            }
            return EVChargeOperator(name: favoriteName)
        }
    }

    public var otherOperators: [EVChargeOperator] {
        let favoriteKeys = Set(favoriteOperatorNames.map { Self.normalizeKey($0) })
        return operatorCatalog.filter { !favoriteKeys.contains(Self.normalizeKey($0.name)) }
    }

    public var locationCatalog: [String] {
        guard chargeMethod != .home else { return [] }

        let normalizedBrand = Self.normalizeKey(stationBrand)
        let baseLocations: [String]
        if !normalizedBrand.isEmpty,
           let byBrand = recentStationLocationsByBrand[normalizedBrand],
           !byBrand.isEmpty {
            baseLocations = byBrand
        } else {
            baseLocations = recentPublicLocations
        }

        let currentLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentLocation.isEmpty else { return baseLocations }
        let currentKey = Self.normalizeKey(currentLocation)
        if baseLocations.contains(where: { Self.normalizeKey($0) == currentKey }) {
            return baseLocations
        }
        return [currentLocation] + baseLocations
    }

    public var isPastDatedEntry: Bool {
        sessionDate < Calendar.current.startOfDay(for: .now)
    }

    public var shouldShowSOCSelection: Bool {
        !isPastDatedEntry || includeSOCForPastDate
    }

    public var socHintText: String {
        "Gecmis tarihli seanslarda Baslangic/Bitis Sarj Yuzdesi secimi opsiyoneldir."
    }

    public var estimatedEnergyKWh: Double? {
        guard shouldShowSOCSelection else { return nil }
        guard let vehicle = activeVehicle else { return nil }
        let estimated = environment.calculateEstimatedEnergyUseCase.execute(
            batteryCapacityKWh: vehicle.batteryCapacityKWh,
            socStart: socStart,
            socEnd: socEnd
        )
        return estimated > 0 ? estimated : nil
    }

    public var selectedEnergyKWh: Double? {
        if let entered = Self.parseDecimal(energyInput), entered > 0 {
            return entered
        }
        return estimatedEnergyKWh
    }

    public var energyIsEstimated: Bool {
        guard selectedEnergyKWh != nil else { return false }
        return !(Self.parseDecimal(energyInput) ?? 0 > 0)
    }

    public var estimatedTLPerKWh: Double? {
        if let enteredTariff = Self.parseDecimal(tariffPricePerKWh), enteredTariff > 0 {
            return enteredTariff
        }

        guard let price = Self.parseDecimal(totalPrice),
              let energy = selectedEnergyKWh,
              energy > 0 else { return nil }
        return environment.calculateTLPerKWhUseCase.execute(priceTotal: price, energyKWh: energy)
    }

    public var estimatedPriceFromTariff: Double? {
        guard let enteredTariff = Self.parseDecimal(tariffPricePerKWh),
              let energy = selectedEnergyKWh,
              enteredTariff >= 0,
              energy > 0 else { return nil }
        return enteredTariff * energy
    }

    public var estimatedRangeGain: Double? {
        guard let energy = selectedEnergyKWh,
              let vehicle = activeVehicle,
              let consumption = vehicle.factoryConsumptionKWh100km,
              consumption > 0 else { return nil }
        return (energy / consumption) * 100
    }

    public var estimatedChargeSpeedKW: Double? {
        guard let energy = selectedEnergyKWh,
              let durationMinutes = Self.parseDecimal(durationMin),
              durationMinutes > 0 else { return nil }
        let hours = durationMinutes / 60
        guard hours > 0 else { return nil }
        return energy / hours
    }

    public var chargeSpeedValidationMessage: String? {
        guard let speed = estimatedChargeSpeedKW,
              let expectedRange = expectedChargeSpeedRange else { return nil }
        guard !expectedRange.contains(speed) else { return nil }

        return "\(chargeMethod.titleTR) için ortalama hız \(NumberFormatting.oneDecimal(speed)) kW görünüyor. Beklenen aralık \(expectedRangeLabel). Bu kayıt hız analizlerinde dikkate alınmayabilir."
    }

    public var shouldIgnoreChargeSpeedInAnalysis: Bool {
        chargeSpeedValidationMessage != nil
    }

    public var effectiveChargeSpeedKWForAnalysis: Double? {
        shouldIgnoreChargeSpeedInAnalysis ? nil : estimatedChargeSpeedKW
    }

    public var priceCurrencyCode: String {
        sessionCurrencyCode
    }

    public var enteredTotalPrice: Double? {
        Self.parseDecimal(totalPrice)
    }

    public var enteredTariffPrice: Double? {
        Self.parseDecimal(tariffPricePerKWh)
    }

    public var enteredEnergyKWh: Double? {
        Self.parseDecimal(energyInput)
    }

    public var enteredDurationMinutes: Double? {
        Self.parseDecimal(durationMin)
    }

    public var enteredOdometerKM: Double? {
        Self.parseDecimal(odometerKM)
    }

    public var enteredTemperatureC: Double? {
        Self.parseDecimal(outsideTempC)
    }

    public var socValidationMessage: String? {
        guard shouldShowSOCSelection else { return nil }
        if socEnd <= socStart {
            return "Şarj yüzdesi başlangıçtan büyük olmalı."
        }
        return nil
    }

    public var totalPriceValidationMessage: String? {
        guard !totalPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredTotalPrice else {
            return "Toplam tutarı sayı formatında gir."
        }
        if value <= 0 {
            return "Toplam ücret 0'dan büyük olmalı."
        }
        return nil
    }

    public var tariffValidationMessage: String? {
        guard !tariffPricePerKWh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredTariffPrice else {
            return "Tarife ücretini sayı formatında gir."
        }
        if value < 0 {
            return "Tarife ücreti negatif olamaz."
        }
        return nil
    }

    public var energyValidationMessage: String? {
        guard !energyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredEnergyKWh else {
            return "Enerji değerini sayı formatında gir."
        }
        if value <= 0 {
            return "Enerji değeri 0'dan büyük olmalı."
        }
        if value > ValidationLimits.maxEnergyKWh {
            return "Enerji değeri beklenenden yüksek görünüyor."
        }
        return nil
    }

    public var energyPriceConsistencyWarningMessage: String? {
        guard enteredEnergyKWh != nil else { return nil }
        let hasAnyPriceInput =
            enteredTotalPrice != nil ||
            enteredTariffPrice != nil ||
            !totalPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !tariffPricePerKWh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !hasAnyPriceInput else { return nil }
        return "Enerji girdin, toplam ücret veya tarife bilgisi de eklemelisin."
    }

    public var durationValidationMessage: String? {
        guard !durationMin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredDurationMinutes else {
            return "Süreyi sayı formatında gir."
        }
        if value <= 0 {
            return "Süre 0'dan büyük olmalı."
        }
        if value > ValidationLimits.maxDurationMinutes {
            return "Süre 24 saati aşamaz."
        }
        return nil
    }

    public var odometerValidationMessage: String? {
        guard !odometerKM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredOdometerKM else {
            return "Odometre değerini sayı formatında gir."
        }
        if value < 0 {
            return "Odometre negatif olamaz."
        }
        if value > ValidationLimits.maxOdometerKM {
            return "Odometre değeri mantık dışı görünüyor."
        }
        return nil
    }

    public var temperatureValidationMessage: String? {
        guard !outsideTempC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = enteredTemperatureC else {
            return "Sıcaklık değerini sayı formatında gir."
        }
        if value < ValidationLimits.minTemperatureC || value > ValidationLimits.maxTemperatureC {
            return "Sıcaklık aralığı -50°C ile 70°C arasında olmalı."
        }
        return nil
    }

    public var energySummaryFallback: String {
        if !energyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enerji değeri geçerli değil."
        }
        if shouldShowSOCSelection {
            return "SOC veya enerji bilgisi bekleniyor."
        }
        return "Enerji girilirse hesaplanır."
    }

    public var totalSummaryFallback: String {
        if enteredTariffPrice != nil, selectedEnergyKWh == nil {
            return "Tarife için enerji bilgisi gerekli."
        }
        if enteredTotalPrice == nil, enteredTariffPrice == nil {
            return "Toplam veya tarife girildiğinde hesaplanır."
        }
        return "Veri eksik olduğu için hesaplanamadı."
    }

    public var tlPerKWhSummaryFallback: String {
        if selectedEnergyKWh == nil {
            return "Enerji bilgisi girildiğinde hesaplanır."
        }
        if enteredTotalPrice == nil, enteredTariffPrice == nil {
            return "Toplam veya tarife bilgisi gerekli."
        }
        return "Veri eksik olduğu için hesaplanamadı."
    }

    public var speedSummaryFallback: String {
        if enteredDurationMinutes == nil {
            return "Süre girildiğinde hesaplanır."
        }
        if selectedEnergyKWh == nil {
            return "Enerji bilgisi girildiğinde hesaplanır."
        }
        return "Veri eksik olduğu için hesaplanamadı."
    }

    public var rangeSummaryFallback: String {
        if selectedEnergyKWh == nil {
            return "Enerji bilgisi girildiğinde hesaplanır."
        }
        if activeVehicle?.factoryConsumptionKWh100km == nil {
            return "Araç tüketim verisi eksik."
        }
        return "Veri eksik olduğu için hesaplanamadı."
    }

    public var canSave: Bool {
        let hasVehicleContext = editingSession != nil || activeVehicle != nil
        let priceCandidate = enteredTotalPrice ?? estimatedPriceFromTariff
        guard hasVehicleContext,
              let priceCandidate,
              priceCandidate > 0 else { return false }

        let hasValidationIssue =
            socValidationMessage != nil ||
            totalPriceValidationMessage != nil ||
            tariffValidationMessage != nil ||
            energyValidationMessage != nil ||
            durationValidationMessage != nil ||
            odometerValidationMessage != nil ||
            temperatureValidationMessage != nil

        return !hasValidationIssue
    }

    public var draftSignature: String {
        [
            chargeMethod.rawValue,
            String(selectedHomeProfileID),
            stationBrand,
            locationName,
            String(socStart),
            String(socEnd),
            totalPrice,
            tariffPricePerKWh,
            energyInput,
            durationMin,
            odometerKM,
            outsideTempC,
            notes,
            selectedContextTags
                .map(\.rawValue)
                .sorted()
                .joined(separator: ","),
            String(sessionDate.timeIntervalSince1970),
            includeSOCForPastDate ? "1" : "0"
        ]
        .joined(separator: "|")
    }

    public func setTargetSOC(_ target: Double) {
        socEnd = max(socStart, min(100, target))
    }

    public func setChargeMethod(_ method: ChargeMethod) {
        chargeMethod = method
        userDefaults.set(method.rawValue, forKey: PersistenceKeys.lastMethod)
        if method == .home {
            // Ev yönteminde kaynak yalnızca Şarj Varsayılanları ekranındaki ev profilidir.
            applySelectedHomeProfileIfNeeded(onlyIfEmpty: false)
        } else {
            applyLastUsedLocationIfNeeded(onlyIfEmpty: true)
        }
        normalizeSOCSelectionState()
        applyTariffAutofillIfNeeded()
    }

    public func selectHomeProfile(id: Int) {
        guard availableHomeProfiles.contains(where: { $0.id == id }) else { return }
        selectedHomeProfileID = id
        applySelectedHomeProfileIfNeeded(onlyIfEmpty: false)
        applyTariffAutofillIfNeeded()
    }

    public func setSessionDate(_ date: Date) {
        sessionDate = date
        if !isPastDatedEntry {
            includeSOCForPastDate = false
        }
        normalizeSOCSelectionState()
    }

    public func setIncludeSOCForPastDate(_ enabled: Bool) {
        includeSOCForPastDate = enabled
        normalizeSOCSelectionState()
    }

    public func onStationBrandChanged() {
        if !isApplyingAutofill {
            homeProfileWasAutoFilled = false
        }

        // Ev modunda kamusal istasyon geçmişinden lokasyon çekme.
        // Aksi halde kullanıcı ayarlardaki ev lokasyonunu değiştiremez hale gelebiliyor.
        if chargeMethod == .home {
            return
        }

        let normalizedBrand = Self.normalizeKey(stationBrand)
        guard !normalizedBrand.isEmpty else {
            if locationWasAutoFilled {
                applyAutoFilledLocation("")
                locationWasAutoFilled = false
            }
            return
        }

        guard let recentLocation = recentStationLocationByBrand[normalizedBrand] else {
            if locationWasAutoFilled {
                applyAutoFilledLocation("")
                locationWasAutoFilled = false
            }
            return
        }

        let currentLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentLocation.isEmpty || locationWasAutoFilled {
            applyAutoFilledLocation(recentLocation)
            locationWasAutoFilled = true
        }
        applyAutoFilledMethodIfNeeded()
    }

    public func onLocationNameChanged() {
        guard !isApplyingAutofill else { return }
        locationWasAutoFilled = false
        homeProfileWasAutoFilled = false
        applyAutoFilledMethodIfNeeded()
    }

    public func onTariffInputChanged() {
        tariffWasAutoFilled = false
    }

    public func selectOperator(_ operatorName: String) {
        stationBrand = canonicalOperatorName(operatorName)
        onStationBrandChanged()
    }

    public func clearSelectedOperator() {
        stationBrand = ""
        onStationBrandChanged()
    }

    public func selectLocation(_ location: String) {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        locationName = trimmed
        onLocationNameChanged()
    }

    public func clearSelectedLocation() {
        locationName = ""
        onLocationNameChanged()
    }

    public func toggleContextTag(_ tag: ChargeContextTag) {
        if let existingIndex = selectedContextTags.firstIndex(of: tag) {
            selectedContextTags.remove(at: existingIndex)
        } else {
            selectedContextTags.append(tag)
        }

        selectedContextTags.sort { $0.rawValue < $1.rawValue }
    }

    public func hasContextTag(_ tag: ChargeContextTag) -> Bool {
        selectedContextTags.contains(tag)
    }

    public func isOperatorFavorite(_ operatorName: String) -> Bool {
        let targetKey = Self.normalizeKey(operatorName)
        return favoriteOperatorNames.contains { Self.normalizeKey($0) == targetKey }
    }

    public func toggleFavoriteOperator(_ operatorName: String) {
        let canonicalName = canonicalOperatorName(operatorName)
        guard !canonicalName.isEmpty else { return }
        let targetKey = Self.normalizeKey(canonicalName)

        if let index = favoriteOperatorNames.firstIndex(where: { Self.normalizeKey($0) == targetKey }) {
            favoriteOperatorNames.remove(at: index)
        } else {
            favoriteOperatorNames.append(canonicalName)
        }

        favoriteOperatorNames = sortedByCatalog(favoriteOperatorNames)
        persistFavoriteOperators()
    }

    public func repeatLastCharge() {
        guard let plan = smartRepeatPlan else { return }

        applySmartRepeatPrefill(plan.prefill)
    }

    public func applySmartRepeatRecommendation() {
        guard let recommendation = smartRepeatPlan?.recommendation else { return }

        setChargeMethod(recommendation.recommendedMethod)
        if recommendation.recommendedMethod != .home {
            if let templateStation = smartRepeatPlan?.prefill.stationBrand {
                stationBrand = canonicalOperatorName(templateStation)
            }
            if let templateLocation = smartRepeatPlan?.prefill.locationName {
                locationName = templateLocation
            }
            locationWasAutoFilled = false
        }

        if let suggestedTariff = recommendation.suggestedTariffPricePerKWh,
           suggestedTariff > 0 {
            tariffPricePerKWh = Self.formatDecimal(suggestedTariff)
            tariffWasAutoFilled = false
        }
    }

    public func applyQuickPreset(_ preset: QuickChargePreset) {
        let prefill = preset.prefill

        if let selectedHomeProfileID = prefill.selectedHomeProfileID,
           availableHomeProfiles.contains(where: { $0.id == selectedHomeProfileID }) {
            self.selectedHomeProfileID = selectedHomeProfileID
        }

        setChargeMethod(prefill.chargeMethod)

        if let stationBrand = prefill.stationBrand {
            self.stationBrand = canonicalOperatorName(stationBrand)
        }

        if let locationName = prefill.locationName {
            self.locationName = locationName
            locationWasAutoFilled = false
        }

        if let tariff = prefill.tariffPricePerKWh, tariff > 0 {
            tariffPricePerKWh = Self.formatDecimal(tariff)
            tariffWasAutoFilled = false
        }

        if let startSOC = prefill.suggestedSOCStart {
            socStart = startSOC
        }

        if let endSOC = prefill.suggestedSOCEnd {
            socEnd = endSOC
        }

        if let duration = prefill.suggestedDurationMinutes, duration > 0 {
            durationMin = String(Int(duration.rounded()))
        }

        normalizeSOCSelectionState()
        refreshLiveInsightNow()
    }

    public func applySmartFavoriteStation(_ suggestion: SmartFavoriteStationSuggestion) {
        setChargeMethod(suggestion.suggestedChargeMethod)

        if let stationBrand = suggestion.stationBrand,
           !stationBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.stationBrand = canonicalOperatorName(stationBrand)
        }

        if let locationName = suggestion.locationName,
           !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.locationName = locationName
            locationWasAutoFilled = false
        }

        if let averageTariff = suggestion.averageTLPerKWh,
           averageTariff > 0 {
            tariffPricePerKWh = Self.formatDecimal(averageTariff)
            tariffWasAutoFilled = false
        }

        normalizeSOCSelectionState()
        refreshLiveInsightNow()
    }

    public func applySuggestedDefaultChargeType(_ type: SuggestedChargeDefaultType) {
        setChargeMethod(type.chargeMethod)
        refreshLiveInsightNow()
    }

    public func applyPlanRecommendation() {
        guard let method = planRecommendation?.suggestedChargeType else { return }
        clearSkippedPlanRecommendation()
        setChargeMethod(method)
        refreshLiveInsightNow()
    }

    public func skipPlanRecommendation(referenceDate: Date = .now) {
        guard let recommendation = planRecommendation else { return }
        userDefaults.set(recommendation.id, forKey: PersistenceKeys.skippedPlanRecommendationID)
        userDefaults.set(referenceDate, forKey: PersistenceKeys.skippedPlanRecommendationAt)
        planRecommendation = nil
    }

    public func scheduleLiveInsightRefresh() {
        liveInsightTask?.cancel()

        // Typing into the form should not trigger a full recalculation on every keystroke.
        liveInsightTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshLiveInsightNow()
        }
    }

    public func refreshLiveInsightNow() {
        guard isSmartRecommendationsEnabled else {
            liveInsight = nil
            return
        }

        guard let activeVehicle else {
            liveInsight = nil
            return
        }

        let input = ChargeFormInsightInput(
            vehicle: activeVehicle,
            chargeMethod: chargeMethod,
            priceTotal: enteredTotalPrice,
            tariffPricePerKWh: enteredTariffPrice,
            fallbackTariffPricePerKWh: selectedHomeProfileTariffPerKWh() ?? defaultElectricityTariffPerKWh,
            energyKWh: selectedEnergyKWh,
            energyIsEstimated: energyIsEstimated,
            durationMinutes: enteredDurationMinutes,
            odometerKM: enteredOdometerKM,
            currencyCode: sessionCurrencyCode
        )

        liveInsight = environment.chargeFormInsightService.makeInsight(
            input: input,
            history: historicalSessions
        )
    }

    private func applySmartRepeatPrefill(_ prefill: SmartRepeatChargePrefill) {
        setChargeMethod(prefill.chargeMethod)
        stationBrand = canonicalOperatorName(prefill.stationBrand ?? "")
        locationName = prefill.locationName ?? ""
        locationWasAutoFilled = false

        if let tariff = prefill.tariffPricePerKWh, tariff > 0 {
            tariffPricePerKWh = Self.formatDecimal(tariff)
            tariffWasAutoFilled = false
        }
    }

    public func persistDraft() {
        guard editingSession == nil, isDraftPersistenceEnabled else { return }
        guard hasMeaningfulDraftContent else {
            clearDraft()
            return
        }

        let payload = DraftPayload(
            chargeMethodRaw: chargeMethod.rawValue,
            selectedHomeProfileID: selectedHomeProfileID,
            stationBrand: stationBrand,
            locationName: locationName,
            socStart: socStart,
            socEnd: socEnd,
            totalPrice: totalPrice,
            tariffPricePerKWh: tariffPricePerKWh,
            energyInput: energyInput,
            durationMin: durationMin,
            odometerKM: odometerKM,
            outsideTempC: outsideTempC,
            notes: notes,
            contextTagRawValues: selectedContextTags.map(\.rawValue),
            sessionDate: sessionDate,
            includeSOCForPastDate: includeSOCForPastDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(payload)
            userDefaults.set(data, forKey: PersistenceKeys.draft)
        } catch {
            environment.crashReporter.log("AddCharge draft encode failed: \(error)")
        }
    }

    public func clearDraft() {
        userDefaults.removeObject(forKey: PersistenceKeys.draft)
    }

    public func loadActiveVehicle() {
        do {
            refreshFeatureFlags()
            activeVehicle = try environment.vehicleRepository.fetchActiveVehicle()
            loadRecentStationLocations()
            loadSmartRepeatPlan()
            loadBehaviorPlan()
            refreshLiveInsightNow()
        } catch {
            latestRepeatTemplateSession = nil
            historicalSessions = []
            predictiveDefaults = nil
            smartFavoriteStations = nil
            smartRepeatPlan = nil
            liveInsight = nil
            activePlan = nil
            planRecommendation = nil
            message = error.localizedDescription
        }
    }

    public func refreshChargingDefaults() {
        refreshFeatureFlags()
        loadSettingsDefaults()
        loadHomeChargingPreferences()
        if !isEditing {
            loadSmartRepeatPlan()
        }
        loadBehaviorPlan()
        if chargeMethod == .home {
            applySelectedHomeProfileIfNeeded(onlyIfEmpty: false)
            applyTariffAutofillIfNeeded()
        }
        refreshLiveInsightNow()
    }

    public func save() -> AddChargeSaveResult {
        guard canSave else {
            message = blockingValidationMessage ?? "Kaydetmek için gerekli alanları tamamla."
            return .failure
        }

        let shouldShowFirstChargeCelebration = shouldShowFirstChargeCelebrationOnSave()

        let vehicleID: UUID
        if let editingSession {
            vehicleID = editingSession.vehicleID
        } else {
            guard let vehicle = activeVehicle else {
                message = "Once aktif bir arac secin"
                return .failure
            }
            vehicleID = vehicle.id
        }

        let price = Self.parseDecimal(totalPrice) ?? estimatedPriceFromTariff
        guard let price, price >= 0 else {
            message = "Toplam tutari veya tarife ucretini girin"
            return .failure
        }

        let socValues = resolvedSOCValues()

        let session = ChargingSession(
            id: editingSession?.id ?? UUID(),
            vehicleID: vehicleID,
            sessionDate: sessionDate,
            chargeMethod: chargeMethod,
            stationBrand: stationBrand.isEmpty ? nil : stationBrand,
            locationName: locationName.isEmpty ? nil : locationName,
            priceTotal: price,
            currencyCode: sessionCurrencyCode,
            energyKWh: selectedEnergyKWh,
            energyIsEstimated: energyIsEstimated,
            socStart: socValues.start,
            socEnd: socValues.end,
            isFullCharge: socValues.isFullCharge,
            durationMin: Self.parseDuration(durationMin),
            odometerKM: Self.parseDecimal(odometerKM),
            outsideTempC: Self.parseDecimal(outsideTempC),
            rangeGainedKmEstimate: estimatedRangeGain,
            contextTags: selectedContextTags,
            notes: notes.isEmpty ? nil : notes,
            createdAt: editingSession?.createdAt ?? .now,
            updatedAt: .now
        )

        do {
            let existingSessions = try environment.listChargingSessionsUseCase.execute(vehicleID: vehicleID)
            let scoringHistory = existingSessions.filter { $0.id != session.id } + [session]
            let vehicleForScoring = editingSession != nil
                ? (try environment.vehicleRepository.fetchVehicles().first { $0.id == vehicleID } ?? activeVehicle)
                : activeVehicle
            let realtimeUpdate = try environment.logChargingSessionUseCase.execute(session)
            latestRealtimeMetricsUpdate = realtimeUpdate
            refreshWidgetSummary()
            environment.analytics.track(.chargeAdded)
            persistLastUsedValues(from: session)
            isDraftPersistenceEnabled = false
            clearDraft()
            let sessionScore = vehicleForScoring.map {
                environment.chargeSessionScoringService.score(
                    session: session,
                    vehicle: $0,
                    history: scoringHistory
                )
            }

            if shouldScheduleUnplugReminder(for: session) {
                let reminderMinutes = max(15, Self.parseDuration(durationMin) ?? 30)
                Task { @MainActor in
                    await environment.unplugReminderScheduler.requestAuthorization()
                    await environment.unplugReminderScheduler.scheduleReminder(
                        after: reminderMinutes,
                        title: unplugReminderTitle(for: session),
                        message: unplugReminderMessage(for: session)
                    )
                }
            }

            if shouldShowFirstChargeCelebration {
                userDefaults.set(true, forKey: PersistenceKeys.firstChargeCelebrationShown)
            }

            message = nil
            return .success(
                AddChargeSaveSuccessPayload(
                    showFirstChargeCelebration: shouldShowFirstChargeCelebration,
                    sessionScore: sessionScore,
                    planFeedbackMessage: planFeedbackMessage(for: session),
                    realtimeMetricsUpdate: realtimeUpdate
                )
            )
        } catch {
            message = error.localizedDescription
            return .failure
        }
    }

    private func refreshWidgetSummary() {
        do {
            let latestSnapshot = try environment.getDashboardSnapshotUseCase.execute()
            WidgetSharedStore.save(snapshot: latestSnapshot)
        } catch {
            // Widget ozeti kritik akis degil; hata durumunda kayit akisini kesmeyelim.
        }
    }

    private func loadBehaviorPlan() {
        guard isSmartRecommendationsEnabled,
              let vehicle = activeVehicle else {
            activePlan = nil
            planRecommendation = nil
            return
        }

        do {
            let usageMode = environment.usageModeStore.loadUsageMode()
            let sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: vehicle.id)
            let goals = try environment.goalRepository.fetchGoals()
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let report = sessions.isEmpty
                ? nil
                : environment.chargeInsightService.analyze(
                    vehicle: vehicle,
                    sessions: sessions,
                    referenceDate: sessionDate
                )
            let savingsReport = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: sessions,
                preferences: baseline,
                referenceDate: sessionDate
            )
            let suggestedGoals = environment.goalSuggestionEngine.suggest(
                input: GoalSuggestionInput(
                    usageMode: usageMode,
                    report: report,
                    savingsReport: savingsReport,
                    sessions: sessions,
                    referenceDate: sessionDate
                )
            )
            let confidence = environment.confidenceScoreEngine.evaluate(
                ConfidenceScoreInput(
                    sampleCount: report?.overall.sessionCount ?? sessions.count,
                    dataConfidence: report?.overall.averageTLPer100Km.confidence,
                    hasCostData: savingsReport.thisMonth?.costPerKWh != nil || !sessions.isEmpty,
                    hasDistanceData: savingsReport.thisMonth?.estimatedDistanceKm ?? 0 > 0
                )
            )
            let basePlan = environment.monthlyPlanEngine.buildPlan(
                MonthlyPlanInput(
                    usageMode: usageMode,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    sessions: sessions,
                    referenceDate: sessionDate
                ),
                confidence: confidence
            )
            activePlan = environment.habitProgressEngine.evaluate(
                PlanProgressInput(
                    plan: basePlan,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    sessions: sessions,
                    referenceDate: sessionDate
                )
            )
            let recommendedAction = environment.recommendationEngine.buildRecommendations(
                RecommendationInput(
                    usageMode: usageMode,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    referenceDate: sessionDate
                )
            ).first
            if let recommendedAction,
               shouldSuppressPlanRecommendation(recommendedAction, referenceDate: sessionDate) {
                planRecommendation = nil
            } else {
                planRecommendation = recommendedAction
            }
        } catch {
            activePlan = nil
            planRecommendation = nil
        }
    }

    private func planFeedbackMessage(for session: ChargingSession) -> String? {
        guard let recommendation = planRecommendation else {
            return nil
        }

        if recommendation.suggestedChargeType == session.chargeMethod {
            return "Bu seçim aktif planını ilerletti."
        }

        return nil
    }

    private func shouldScheduleUnplugReminder(for session: ChargingSession) -> Bool {
        guard !isEditing, session.chargeMethod != .home else { return false }

        let distanceToNow = abs(session.sessionDate.timeIntervalSinceNow)
        guard distanceToNow <= (15 * 60) else { return false }

        return true
    }

    private func shouldSuppressPlanRecommendation(
        _ recommendation: Recommendation,
        referenceDate: Date
    ) -> Bool {
        guard let skippedID = userDefaults.string(forKey: PersistenceKeys.skippedPlanRecommendationID),
              let skippedAt = userDefaults.object(forKey: PersistenceKeys.skippedPlanRecommendationAt) as? Date,
              skippedID == recommendation.id else {
            return false
        }

        return referenceDate.timeIntervalSince(skippedAt) < BehaviorConstants.skippedRecommendationSuppressionInterval
    }

    private func clearSkippedPlanRecommendation() {
        userDefaults.removeObject(forKey: PersistenceKeys.skippedPlanRecommendationID)
        userDefaults.removeObject(forKey: PersistenceKeys.skippedPlanRecommendationAt)
    }

    private func unplugReminderTitle(for session: ChargingSession) -> String {
        if let station = session.stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines),
           !station.isEmpty {
            return "\(station) seansini kontrol et"
        }

        switch session.chargeMethod {
        case .home:
            return "Ev sarjini kontrol et"
        case .publicAC:
            return "AC sarj seansini kontrol et"
        case .publicDC:
            return "DC sarj seansini kontrol et"
        }
    }

    private func unplugReminderMessage(for session: ChargingSession) -> String {
        let location = session.locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let station = session.stationBrand?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let station, !station.isEmpty, let location, !location.isEmpty {
            return "\(station) - \(location) seansini kontrol et. Bittiysen araci prizden ayir."
        }

        if let station, !station.isEmpty {
            return "\(station) seansini kontrol et. Bittiysen araci prizden ayir."
        }

        if let location, !location.isEmpty {
            return "\(location) seansini kontrol et. Bittiysen araci prizden ayir."
        }

        return "Sarj seansini kontrol et. Bittiysen araci prizden ayir."
    }

    private func applyEditingValues(from session: ChargingSession) {
        chargeMethod = session.chargeMethod
        sessionCurrencyCode = session.currencyCode
        stationBrand = canonicalOperatorName(session.stationBrand ?? "")
        locationName = session.locationName ?? ""
        locationWasAutoFilled = false
        socStart = session.socStart
        socEnd = session.socEnd
        includeSOCForPastDate = session.sessionDate < Calendar.current.startOfDay(for: .now) &&
            (session.socStart > 0 || session.socEnd > 0)
        totalPrice = Self.formatDecimal(session.priceTotal)
        if let energy = session.energyKWh {
            energyInput = Self.formatDecimal(energy)
            if energy > 0 {
                tariffPricePerKWh = Self.formatDecimal(session.priceTotal / energy)
            }
        }
        durationMin = session.durationMin.map(String.init) ?? ""
        odometerKM = session.odometerKM.map(Self.formatDecimal) ?? ""
        outsideTempC = session.outsideTempC.map(Self.formatDecimal) ?? ""
        notes = session.notes ?? ""
        selectedContextTags = session.contextTags.sorted { $0.rawValue < $1.rawValue }
        sessionDate = session.sessionDate
    }

    private func applyLastUsedDefaults() {
        if let rawMethod = userDefaults.string(forKey: PersistenceKeys.lastMethod),
           let rememberedMethod = ChargeMethod(rawValue: rawMethod) {
            chargeMethod = rememberedMethod
        }

        if chargeMethod != .home {
            applyLastUsedLocationIfNeeded(onlyIfEmpty: false)
        }
        applyLastUsedTariffIfNeeded(onlyIfEmpty: false)
    }

    private func restoreDraftIfAvailable() {
        guard let data = userDefaults.data(forKey: PersistenceKeys.draft),
              let payload = Self.decodeDraftPayload(from: data) else { return }

        hasRestoredDraft = true

        if let draftMethod = ChargeMethod(rawValue: payload.chargeMethodRaw) {
            chargeMethod = draftMethod
        }
        if availableHomeProfiles.contains(where: { $0.id == payload.selectedHomeProfileID }) {
            selectedHomeProfileID = payload.selectedHomeProfileID
        }
        if chargeMethod == .home {
            // Ev profil bilgisi ayarlardan gelmeli; taslak bu iki alanı geri getirmez.
            stationBrand = ""
            locationName = ""
        } else {
            stationBrand = canonicalOperatorName(payload.stationBrand)
            locationName = payload.locationName
        }
        socStart = payload.socStart
        socEnd = payload.socEnd
        totalPrice = payload.totalPrice
        tariffPricePerKWh = payload.tariffPricePerKWh
        energyInput = payload.energyInput
        durationMin = payload.durationMin
        odometerKM = payload.odometerKM
        outsideTempC = payload.outsideTempC
        notes = payload.notes
        selectedContextTags = (payload.contextTagRawValues ?? [])
            .compactMap(ChargeContextTag.init(rawValue:))
            .sorted { $0.rawValue < $1.rawValue }
        sessionDate = payload.sessionDate
        includeSOCForPastDate = payload.includeSOCForPastDate
        locationWasAutoFilled = false
        tariffWasAutoFilled = false

        if chargeMethod == .home {
            // Ev modunda taslak değerleri yerine ayarlardaki ev profili önceliklidir.
            applySelectedHomeProfileIfNeeded(onlyIfEmpty: false)
        }
    }

    private func persistLastUsedValues(from session: ChargingSession) {
        userDefaults.set(session.chargeMethod.rawValue, forKey: PersistenceKeys.lastMethod)

        let tariffToRemember = enteredTariffPrice ?? session.tlPerKWh
        if let tariffToRemember, tariffToRemember > 0 {
            userDefaults.set(tariffToRemember, forKey: Self.lastTariffKey(for: session.chargeMethod))
            userDefaults.set(tariffToRemember, forKey: PersistenceKeys.legacyLastTariff)
        }

        let station = session.stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = session.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch session.chargeMethod {
        case .home:
            if let station, !station.isEmpty {
                userDefaults.set(station, forKey: PersistenceKeys.lastHomeStation)
            }
            if let location, !location.isEmpty {
                userDefaults.set(location, forKey: PersistenceKeys.lastHomeLocation)
            }
        case .publicAC, .publicDC:
            if let station, !station.isEmpty {
                userDefaults.set(station, forKey: PersistenceKeys.lastPublicStation)
            }
            if let location, !location.isEmpty {
                userDefaults.set(location, forKey: PersistenceKeys.lastPublicLocation)
            }
        }

        if let station, !station.isEmpty,
           let location, !location.isEmpty {
            recentStationLocationByBrand[Self.normalizeKey(station)] = location
            recentStationMethodByBrandLocation[Self.stationKey(brand: station, location: location)] = session.chargeMethod
        }
    }

    private func loadRecentStationLocations() {
        do {
            let vehicleID = editingSession?.vehicleID ?? activeVehicle?.id
            let sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: vehicleID)
                .sorted(by: { $0.sessionDate > $1.sessionDate })

            var mapping: [String: String] = [:]
            var locationsByBrand: [String: [String]] = [:]
            var allPublicLocations: [String] = []
            var methodMapping: [String: ChargeMethod] = [:]
            for session in sessions {
                let brand = session.stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let location = session.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if !location.isEmpty,
                   session.chargeMethod != .home {
                    let normalizedLocation = Self.normalizeKey(location)
                    if !allPublicLocations.contains(where: { Self.normalizeKey($0) == normalizedLocation }) {
                        allPublicLocations.append(location)
                    }
                }

                guard !brand.isEmpty, !location.isEmpty else { continue }

                let brandKey = Self.normalizeKey(brand)
                let stationKey = Self.stationKey(brand: brand, location: location)

                if mapping[brandKey] == nil {
                    mapping[brandKey] = location
                }

                var locations = locationsByBrand[brandKey] ?? []
                let normalizedLocation = Self.normalizeKey(location)
                if !locations.contains(where: { Self.normalizeKey($0) == normalizedLocation }) {
                    locations.append(location)
                }
                locationsByBrand[brandKey] = locations

                if methodMapping[stationKey] == nil {
                    methodMapping[stationKey] = session.chargeMethod
                }
            }
            recentStationLocationByBrand = mapping
            recentStationLocationsByBrand = locationsByBrand
            recentPublicLocations = allPublicLocations
            recentStationMethodByBrandLocation = methodMapping
            if !hasRestoredDraft {
                applyAutoFilledMethodIfNeeded()
            }
        } catch {
            // Autofill olmadiginda ekran akisina engel olmasin.
            recentStationLocationByBrand = [:]
            recentStationLocationsByBrand = [:]
            recentPublicLocations = []
            recentStationMethodByBrandLocation = [:]
        }
    }

    private func loadSettingsDefaults() {
        do {
            let settings = try environment.settingsRepository.getFuelBaseline()
            sessionCurrencyCode = settings.currencyCode
            defaultElectricityTariffPerKWh = settings.electricityPricePerKWh
        } catch {
            sessionCurrencyCode = AppConstants.defaultCurrencyCode
            defaultElectricityTariffPerKWh = nil
        }
    }

    private func loadHomeChargingPreferences() {
        let preferences = HomeChargingPreferencesStore.load(defaults: userDefaults)
        availableHomeProfiles = preferences.enabledProfiles
        selectedHomeProfileID = preferences.defaultProfile?.id ?? 1
    }

    private func loadFavoriteOperators() {
        let storedNames = userDefaults.stringArray(forKey: PersistenceKeys.favoriteOperators) ?? []
        var unique: [String] = []

        for rawName in storedNames {
            let canonicalName = canonicalOperatorName(rawName)
            guard !canonicalName.isEmpty else { continue }
            if unique.contains(where: { Self.normalizeKey($0) == Self.normalizeKey(canonicalName) }) {
                continue
            }
            unique.append(canonicalName)
        }

        favoriteOperatorNames = sortedByCatalog(unique)
    }

    private func persistFavoriteOperators() {
        userDefaults.set(favoriteOperatorNames, forKey: PersistenceKeys.favoriteOperators)
    }

    private func loadSmartRepeatPlan() {
        guard isSmartRecommendationsEnabled else {
            latestRepeatTemplateSession = nil
            historicalSessions = []
            predictiveDefaults = nil
            smartFavoriteStations = nil
            smartRepeatPlan = nil
            liveInsight = nil
            return
        }

        guard let vehicleID = activeVehicle?.id else {
            latestRepeatTemplateSession = nil
            historicalSessions = []
            predictiveDefaults = nil
            smartFavoriteStations = nil
            smartRepeatPlan = nil
            liveInsight = nil
            return
        }

        do {
            let sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: vehicleID)
            historicalSessions = sessions
            predictiveDefaults = !isEditing ? environment.predictiveChargeDefaultsService.makeReport(
                sessions: sessions,
                availableHomeProfiles: availableHomeProfiles,
                selectedHomeProfileID: selectedHomeProfileID,
                defaultElectricityTariffPerKWh: defaultElectricityTariffPerKWh
            ) : nil
            smartFavoriteStations = !isEditing ? environment.smartFavoriteStationService.makeReport(
                sessions: sessions
            ) : nil
            if !isEditing, let vehicle = activeVehicle {
                latestRepeatTemplateSession = sessions.max(by: { $0.sessionDate < $1.sessionDate })
                smartRepeatPlan = environment.smartRepeatChargeUseCase.execute(
                    vehicle: vehicle,
                    sessions: sessions,
                    electricityPricePerKWh: defaultElectricityTariffPerKWh
                )
            } else {
                latestRepeatTemplateSession = nil
                smartRepeatPlan = nil
            }
            refreshLiveInsightNow()
        } catch {
            latestRepeatTemplateSession = nil
            historicalSessions = []
            predictiveDefaults = nil
            smartFavoriteStations = nil
            smartRepeatPlan = nil
            refreshLiveInsightNow()
        }
    }

    private func refreshFeatureFlags() {
        isSmartRecommendationsEnabled = environment.featureAccessChecker.isEnabled(.smartRecommendations)
        smartRecommendationsEnabled = isSmartRecommendationsEnabled
    }

    private func shouldShowFirstChargeCelebrationOnSave() -> Bool {
        guard !isEditing else { return false }
        guard !userDefaults.bool(forKey: PersistenceKeys.firstChargeCelebrationShown) else { return false }
        do {
            let existingSessions = try environment.listChargingSessionsUseCase.execute(vehicleID: nil)
            return existingSessions.isEmpty
        } catch {
            return false
        }
    }

    private var blockingValidationMessage: String? {
        if let message = socValidationMessage { return message }
        if let message = totalPriceValidationMessage { return message }
        if let message = tariffValidationMessage { return message }
        if let message = energyValidationMessage { return message }
        if let message = durationValidationMessage { return message }
        if let message = odometerValidationMessage { return message }
        if let message = temperatureValidationMessage { return message }
        if let message = energyPriceConsistencyWarningMessage { return message }

        if enteredTotalPrice == nil, enteredTariffPrice == nil {
            return "Toplam ücret 0'dan büyük olmalı."
        }
        return nil
    }

    private var expectedChargeSpeedRange: ClosedRange<Double>? {
        switch chargeMethod {
        case .publicAC:
            return ValidationLimits.minACSpeedKW...ValidationLimits.maxACSpeedKW
        case .publicDC:
            return ValidationLimits.minDCSpeedKW...ValidationLimits.maxDCSpeedKW
        case .home:
            return nil
        }
    }

    private var expectedRangeLabel: String {
        switch chargeMethod {
        case .publicAC:
            return "\(Int(ValidationLimits.minACSpeedKW))-\(Int(ValidationLimits.maxACSpeedKW)) kW"
        case .publicDC:
            return "\(Int(ValidationLimits.minDCSpeedKW))-\(Int(ValidationLimits.maxDCSpeedKW)) kW"
        case .home:
            return "-"
        }
    }

    private func normalizeSOCSelectionState() {
        guard shouldShowSOCSelection else { return }
        if socStart == 0, socEnd == 0 {
            socStart = 20
            socEnd = 80
        } else if socEnd < socStart {
            socEnd = socStart
        }
    }

    private func resolvedSOCValues() -> (start: Double, end: Double, isFullCharge: Bool) {
        if shouldShowSOCSelection {
            return (socStart, socEnd, socEnd >= 100)
        }
        if let editingSession {
            return (editingSession.socStart, editingSession.socEnd, editingSession.isFullCharge)
        }
        return (0, 0, false)
    }

    private func applyAutoFilledLocation(_ value: String) {
        isApplyingAutofill = true
        locationName = value
        isApplyingAutofill = false
    }

    private func applySelectedHomeProfileIfNeeded(onlyIfEmpty: Bool) {
        guard chargeMethod == .home else { return }
        guard let profile = availableHomeProfiles.first(where: { $0.id == selectedHomeProfileID }) else { return }

        let profileName = profile.trimmedName
        let profileLocation = profile.trimmedLocation
        guard !profileName.isEmpty || !profileLocation.isEmpty else { return }

        isApplyingAutofill = true
        defer { isApplyingAutofill = false }

        if !profileName.isEmpty,
           shouldApplyAutofill(currentValue: stationBrand, onlyIfEmpty: onlyIfEmpty || !homeProfileWasAutoFilled) {
            stationBrand = profileName
            homeProfileWasAutoFilled = true
        }

        if !profileLocation.isEmpty,
           shouldApplyAutofill(currentValue: locationName, onlyIfEmpty: onlyIfEmpty || !homeProfileWasAutoFilled) {
            locationName = profileLocation
            locationWasAutoFilled = true
            homeProfileWasAutoFilled = true
        }
    }

    private func applyAutoFilledMethodIfNeeded() {
        guard !isEditing else { return }
        let key = Self.stationKey(brand: stationBrand, location: locationName)
        guard !key.isEmpty,
              let method = recentStationMethodByBrandLocation[key] else { return }
        if chargeMethod != method {
            chargeMethod = method
            normalizeSOCSelectionState()
            applyTariffAutofillIfNeeded()
        }
    }

    private func applyTariffAutofillIfNeeded() {
        guard !isEditing else { return }

        if chargeMethod == .home {
            let preferredTariff = selectedHomeProfileTariffPerKWh() ?? defaultElectricityTariffPerKWh
            guard let preferredTariff, preferredTariff > 0 else { return }

            let shouldAutofill = shouldApplyAutofill(
                currentValue: tariffPricePerKWh,
                onlyIfEmpty: !tariffWasAutoFilled
            )
            if shouldAutofill {
                tariffPricePerKWh = Self.formatDecimal(preferredTariff)
                tariffWasAutoFilled = true
            }
        } else if tariffWasAutoFilled {
            tariffPricePerKWh = ""
            tariffWasAutoFilled = false
        }
    }

    private func applyLastUsedLocationIfNeeded(onlyIfEmpty: Bool) {
        switch chargeMethod {
        case .home:
            return
        case .publicAC, .publicDC:
            let stationKey = PersistenceKeys.lastPublicStation
            let locationKey = PersistenceKeys.lastPublicLocation

            if let rememberedStation = userDefaults.string(forKey: stationKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !rememberedStation.isEmpty,
               shouldApplyAutofill(currentValue: stationBrand, onlyIfEmpty: onlyIfEmpty) {
                stationBrand = rememberedStation
            }

            if let rememberedLocation = userDefaults.string(forKey: locationKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !rememberedLocation.isEmpty,
               shouldApplyAutofill(currentValue: locationName, onlyIfEmpty: onlyIfEmpty) {
                applyAutoFilledLocation(rememberedLocation)
                locationWasAutoFilled = true
            }
        }
    }

    private func applyLastUsedTariffIfNeeded(onlyIfEmpty: Bool) {
        guard !isEditing else { return }
        guard shouldApplyAutofill(currentValue: tariffPricePerKWh, onlyIfEmpty: onlyIfEmpty) || tariffWasAutoFilled else {
            return
        }

        if let remembered = userDefaults.object(forKey: Self.lastTariffKey(for: chargeMethod)) as? Double,
           remembered > 0 {
            tariffPricePerKWh = Self.formatDecimal(remembered)
            tariffWasAutoFilled = true
            return
        }

        if let legacyRemembered = userDefaults.object(forKey: PersistenceKeys.legacyLastTariff) as? Double,
           legacyRemembered > 0 {
            tariffPricePerKWh = Self.formatDecimal(legacyRemembered)
            tariffWasAutoFilled = true
        }
    }

    private var hasMeaningfulDraftContent: Bool {
        let hasTextInput =
            !stationBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !totalPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !tariffPricePerKWh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !energyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !durationMin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !odometerKM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !outsideTempC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !selectedContextTags.isEmpty

        let defaultDateDelta = abs(sessionDate.timeIntervalSinceNow)
        let hasNonDefaultState =
            chargeMethod != .home ||
            includeSOCForPastDate ||
            abs(socStart - 20) > 0.5 ||
            abs(socEnd - 80) > 0.5 ||
            defaultDateDelta > 300

        return hasTextInput || hasNonDefaultState
    }

    private func shouldApplyAutofill(currentValue: String, onlyIfEmpty: Bool) -> Bool {
        if !onlyIfEmpty {
            return true
        }
        return currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func lastTariffKey(for method: ChargeMethod) -> String {
        switch method {
        case .home:
            return PersistenceKeys.lastTariffHome
        case .publicAC:
            return PersistenceKeys.lastTariffPublicAC
        case .publicDC:
            return PersistenceKeys.lastTariffPublicDC
        }
    }

    private func selectedHomeProfileTariffPerKWh() -> Double? {
        guard chargeMethod == .home else { return nil }
        guard let selectedProfile = availableHomeProfiles.first(where: { $0.id == selectedHomeProfileID }) else {
            return nil
        }
        guard let tariff = selectedProfile.tariffPricePerKWh, tariff > 0 else {
            return nil
        }
        return tariff
    }

    private static func decodeDraftPayload(from data: Data) -> DraftPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(DraftPayload.self, from: data)
        } catch {
            #if DEBUG
            print("[AddCharge] Draft decode failed: \(error)")
            #endif
            return nil
        }
    }

    private func canonicalOperatorName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = Self.normalizeKey(trimmed)
        if let matched = EVChargeOperator.turkiye.first(where: {
            Self.normalizeKey($0.name) == normalized
        }) {
            return matched.name
        }
        return trimmed
    }

    private func sortedByCatalog(_ names: [String]) -> [String] {
        let indexMap = Dictionary(uniqueKeysWithValues: EVChargeOperator.turkiye.enumerated().map {
            (Self.normalizeKey($0.element.name), $0.offset)
        })

        return names.sorted { lhs, rhs in
            let lhsKey = Self.normalizeKey(lhs)
            let rhsKey = Self.normalizeKey(rhs)
            let lhsIndex = indexMap[lhsKey] ?? Int.max
            let rhsIndex = indexMap[rhsKey] ?? Int.max
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func stationKey(brand: String, location: String) -> String {
        let brandKey = normalizeKey(brand)
        let locationKey = normalizeKey(location)
        guard !brandKey.isEmpty, !locationKey.isEmpty else { return "" }
        return "\(brandKey)|\(locationKey)"
    }

    private static func normalizeKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private static func formatDecimal(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        var formatted = String(format: "%.2f", value)
        while formatted.contains("."),
              (formatted.hasSuffix("0") || formatted.hasSuffix(".")) {
            formatted.removeLast()
        }
        return formatted
    }

    private static func parseDuration(_ text: String) -> Int? {
        guard let value = parseDecimal(text) else { return nil }
        return Int(value.rounded())
    }
}
