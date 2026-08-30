import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData
#endif

@MainActor
public final class AppEnvironment: ObservableObject {
    public let analytics: AnalyticsTracking
    public let crashReporter: CrashReporting
    public let vehicleCatalog: ReferenceVehicleCatalogProviding
    public let unplugReminderScheduler: UnplugReminderScheduling

    public let vehicleRepository: any VehicleRepository
    public let chargingSessionRepository: any ChargingSessionRepository
    public let settingsRepository: any SettingsRepository
    public let goalRepository: any GoalRepository
    public let chargingOperatorRepository: any ChargingOperatorRepository
    public let consumptionBlockRepository: any ConsumptionBlockRepository
    public let vehicleMetricSnapshotRepository: any VehicleMetricSnapshotRepository

    public let createVehicleUseCase: CreateVehicleUseCase
    public let updateVehicleUseCase: UpdateVehicleUseCase
    public let deleteVehicleUseCase: DeleteVehicleUseCase
    public let setActiveVehicleUseCase: SetActiveVehicleUseCase
    public let logChargingSessionUseCase: LogChargingSessionUseCase
    public let listChargingSessionsUseCase: ListChargingSessionsUseCase
    public let deleteChargingSessionUseCase: DeleteChargingSessionUseCase
    public let getDashboardSnapshotUseCase: GetDashboardSnapshotUseCase
    public let smartRepeatChargeUseCase: SmartRepeatChargeUseCase
    public let chargeRecordService: ChargeRecordService

    public let calculateEstimatedEnergyUseCase: CalculateEstimatedEnergyUseCase
    public let calculateTLPerKWhUseCase: CalculateTLPerKWhUseCase
    public let calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase
    public let calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase
    public let calculateGasolineComparisonUseCase: CalculateGasolineComparisonUseCase
    public let savingsCalculationEngine: SavingsCalculationEngine
    public let chargeInsightService: ChargeInsightService
    public let generateActionableInsightsSkill: GenerateActionableInsightsSkill
    public let dailyInsightCoordinator: DailyInsightCoordinator
    public let detectTrendBreakSkill: DetectTrendBreakSkill
    public let trendBreakDetectionService: TrendBreakDetectionService
    public let chargeFormInsightService: ChargeFormInsightService
    public let predictiveChargeDefaultsService: PredictiveChargeDefaultsService
    public let smartFavoriteStationService: SmartFavoriteStationService
    public let chargeSessionScoringService: ChargeSessionScoringService
    public let chargeContextInsightService: ChargeContextInsightService
    public let goalProgressService: GoalProgressService
    public let personalRecordsService: PersonalRecordsService
    public let userChargingProfileService: UserChargingProfileService
    public let analysisConfidenceService: AnalysisConfidenceService
    public let achievementService: AchievementService
    public let retentionPromptService: RetentionPromptService
    public let experimentSuggestionService: ExperimentSuggestionService
    public let usageModeStore: UsageModeStore
    public let goalSuggestionEngine: GoalSuggestionEngine
    public let monthlyPlanEngine: MonthlyPlanEngine
    public let habitProgressEngine: HabitProgressEngine
    public let recommendationEngine: RecommendationEngine
    public let confidenceScoreEngine: ConfidenceScoreEngine
    public let insightComposer: InsightComposer
    public let homeActionCardProvider: HomeActionCardProvider
    public let gasolineComparisonService: GasolineComparisonService
    public let blockSelectionService: BlockSelectionService
    public let consumptionCalculationService: ConsumptionCalculationService
    public let metricsSnapshotService: MetricsSnapshotService
    public let realtimeMetricsProjectionService: RealtimeMetricsProjectionService
    public let metricsEventBus: MetricsEventBus
    public let dashboardCacheService: any DashboardCacheService
    public let featureFlagStore: any FeatureFlagStore
    public let featureAccessChecker: any FeatureAccessChecking

    public init(
        analytics: AnalyticsTracking,
        crashReporter: CrashReporting,
        vehicleCatalog: ReferenceVehicleCatalogProviding,
        unplugReminderScheduler: UnplugReminderScheduling,
        vehicleRepository: any VehicleRepository,
        chargingSessionRepository: any ChargingSessionRepository,
        settingsRepository: any SettingsRepository,
        goalRepository: any GoalRepository,
        chargingOperatorRepository: any ChargingOperatorRepository,
        consumptionBlockRepository: any ConsumptionBlockRepository,
        vehicleMetricSnapshotRepository: any VehicleMetricSnapshotRepository,
        dailyInsightUserDefaults: UserDefaults = .standard,
        featureFlagUserDefaults: UserDefaults? = nil,
        featureFlagStore: (any FeatureFlagStore)? = nil,
        dashboardCacheService: (any DashboardCacheService)? = nil,
        metricsEventBus: MetricsEventBus? = nil
    ) {
        self.analytics = analytics
        self.crashReporter = crashReporter
        self.vehicleCatalog = vehicleCatalog
        self.unplugReminderScheduler = unplugReminderScheduler
        self.vehicleRepository = vehicleRepository
        self.chargingSessionRepository = chargingSessionRepository
        self.settingsRepository = settingsRepository
        self.goalRepository = goalRepository
        self.chargingOperatorRepository = chargingOperatorRepository
        self.consumptionBlockRepository = consumptionBlockRepository
        self.vehicleMetricSnapshotRepository = vehicleMetricSnapshotRepository

        let resolvedFeatureStore = featureFlagStore ?? UserDefaultsFeatureFlagStore(
            defaults: featureFlagUserDefaults ?? dailyInsightUserDefaults
        )
        self.featureFlagStore = resolvedFeatureStore
        self.featureAccessChecker = FeatureAccessChecker(
            store: resolvedFeatureStore,
            bootstrapDefaults: false
        )

        let resolvedDashboardCacheService = dashboardCacheService ?? UserDefaultsDashboardCacheService(
            defaults: dailyInsightUserDefaults
        )
        let resolvedMetricsEventBus = metricsEventBus ?? MetricsEventBus()
        self.dashboardCacheService = resolvedDashboardCacheService
        self.metricsEventBus = resolvedMetricsEventBus

        gasolineComparisonService = GasolineComparisonService()
        blockSelectionService = BlockSelectionService()
        consumptionCalculationService = ConsumptionCalculationService()
        metricsSnapshotService = MetricsSnapshotService(
            gasolineComparisonService: gasolineComparisonService
        )
        realtimeMetricsProjectionService = RealtimeMetricsProjectionService(
            sessionRepository: chargingSessionRepository,
            vehicleRepository: vehicleRepository,
            settingsRepository: settingsRepository,
            blockRepository: consumptionBlockRepository,
            snapshotRepository: vehicleMetricSnapshotRepository,
            dashboardCacheService: resolvedDashboardCacheService,
            blockSelectionService: blockSelectionService,
            consumptionCalculationService: consumptionCalculationService,
            metricsSnapshotService: metricsSnapshotService
        )
        chargeRecordService = ChargeRecordService(
            sessionRepository: chargingSessionRepository,
            metricsEventBus: resolvedMetricsEventBus
        )
        resolvedMetricsEventBus.register { [realtimeMetricsProjectionService] event in
            try realtimeMetricsProjectionService.handle(event: event)
        }

        createVehicleUseCase = CreateVehicleUseCase(repository: vehicleRepository)
        updateVehicleUseCase = UpdateVehicleUseCase(repository: vehicleRepository)
        deleteVehicleUseCase = DeleteVehicleUseCase(vehicleRepository: vehicleRepository, sessionRepository: chargingSessionRepository)
        setActiveVehicleUseCase = SetActiveVehicleUseCase(repository: vehicleRepository)
        logChargingSessionUseCase = LogChargingSessionUseCase(
            repository: chargingSessionRepository,
            chargeRecordService: chargeRecordService
        )
        listChargingSessionsUseCase = ListChargingSessionsUseCase(repository: chargingSessionRepository)
        deleteChargingSessionUseCase = DeleteChargingSessionUseCase(
            repository: chargingSessionRepository,
            chargeRecordService: chargeRecordService
        )
        calculateEstimatedEnergyUseCase = CalculateEstimatedEnergyUseCase()
        calculateTLPerKWhUseCase = CalculateTLPerKWhUseCase()
        calculateEnergyPer100KmUseCase = CalculateEnergyPer100KmUseCase()
        calculateTLPer100KmUseCase = CalculateTLPer100KmUseCase()
        calculateGasolineComparisonUseCase = CalculateGasolineComparisonUseCase()
        savingsCalculationEngine = SavingsCalculationEngine()
        getDashboardSnapshotUseCase = GetDashboardSnapshotUseCase(
            vehicleRepository: vehicleRepository,
            sessionRepository: chargingSessionRepository,
            settingsRepository: settingsRepository,
            savingsCalculationEngine: savingsCalculationEngine,
            vehicleMetricSnapshotRepository: vehicleMetricSnapshotRepository,
            dashboardCacheService: resolvedDashboardCacheService
        )
        chargeInsightService = ChargeInsightService(
            calculateTLPer100KmUseCase: calculateTLPer100KmUseCase
        )
        generateActionableInsightsSkill = GenerateActionableInsightsSkill()
        dailyInsightCoordinator = DailyInsightCoordinator(
            vehicleRepository: vehicleRepository,
            chargingSessionRepository: chargingSessionRepository,
            settingsRepository: settingsRepository,
            userDefaults: dailyInsightUserDefaults
        )
        trendBreakDetectionService = TrendBreakDetectionService(
            calculateEnergyPer100KmUseCase: calculateEnergyPer100KmUseCase
        )
        detectTrendBreakSkill = DetectTrendBreakSkill(
            calculateEnergyPer100KmUseCase: calculateEnergyPer100KmUseCase,
            trendBreakDetectionService: trendBreakDetectionService
        )
        chargeFormInsightService = ChargeFormInsightService(
            calculateTLPer100KmUseCase: calculateTLPer100KmUseCase
        )
        predictiveChargeDefaultsService = PredictiveChargeDefaultsService()
        smartFavoriteStationService = SmartFavoriteStationService()
        chargeSessionScoringService = ChargeSessionScoringService(
            calculateTLPer100KmUseCase: calculateTLPer100KmUseCase
        )
        chargeContextInsightService = ChargeContextInsightService(
            calculateEnergyPer100KmUseCase: calculateEnergyPer100KmUseCase,
            calculateTLPerKWhUseCase: calculateTLPerKWhUseCase
        )
        goalProgressService = GoalProgressService()
        personalRecordsService = PersonalRecordsService()
        userChargingProfileService = UserChargingProfileService()
        analysisConfidenceService = AnalysisConfidenceService()
        achievementService = AchievementService()
        retentionPromptService = RetentionPromptService(userDefaults: dailyInsightUserDefaults)
        experimentSuggestionService = ExperimentSuggestionService()
        usageModeStore = UserDefaultsUsageModeStore(defaults: dailyInsightUserDefaults)
        goalSuggestionEngine = GoalSuggestionEngine()
        monthlyPlanEngine = MonthlyPlanEngine()
        habitProgressEngine = HabitProgressEngine()
        recommendationEngine = RecommendationEngine()
        confidenceScoreEngine = ConfidenceScoreEngine()
        insightComposer = InsightComposer()
        homeActionCardProvider = HomeActionCardProvider()
        smartRepeatChargeUseCase = SmartRepeatChargeUseCase(
            scoringService: chargeSessionScoringService
        )
    }

    public static func live(inMemory: Bool = false) throws -> AppEnvironment {
        #if VOLTLY_ENABLE_SWIFTDATA
        let container = try SwiftDataFactory.makeModelContainer(inMemory: inMemory)
        let context = ModelContext(container)

        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let chargingRepository = SwiftDataChargingSessionRepository(context: context)
        let settingsRepository = SwiftDataSettingsRepository(context: context)
        let goalRepository = UserDefaultsGoalRepository()
        #else
        let vehicleRepository = InMemoryVehicleRepository()
        let chargingRepository = InMemoryChargingSessionRepository()
        let settingsRepository = InMemorySettingsRepository()
        let goalRepository = InMemoryGoalRepository()
        #endif

        #if VOLTLY_ENABLE_SWIFTDATA
        let resolvedGoalRepository: any GoalRepository = inMemory ? InMemoryGoalRepository() : goalRepository
        #else
        let resolvedGoalRepository: any GoalRepository = goalRepository
        #endif

        let dailyInsightUserDefaults: UserDefaults = inMemory
            ? makeIsolatedInMemoryUserDefaults()
            : .standard

        #if VOLTLY_ENABLE_SWIFTDATA
        let consumptionBlockRepository: any ConsumptionBlockRepository = inMemory
            ? InMemoryConsumptionBlockRepository()
            : SwiftDataConsumptionBlockRepository(context: context)
        let vehicleMetricSnapshotRepository: any VehicleMetricSnapshotRepository = inMemory
            ? InMemoryVehicleMetricSnapshotRepository()
            : SwiftDataVehicleMetricSnapshotRepository(context: context)
        #else
        let consumptionBlockRepository: any ConsumptionBlockRepository = inMemory
            ? InMemoryConsumptionBlockRepository()
            : UserDefaultsConsumptionBlockRepository(defaults: dailyInsightUserDefaults)
        let vehicleMetricSnapshotRepository: any VehicleMetricSnapshotRepository = inMemory
            ? InMemoryVehicleMetricSnapshotRepository()
            : UserDefaultsVehicleMetricSnapshotRepository(defaults: dailyInsightUserDefaults)
        #endif
        let resolvedDashboardCacheService: any DashboardCacheService = inMemory
            ? InMemoryDashboardCacheService()
            : UserDefaultsDashboardCacheService(defaults: dailyInsightUserDefaults)

        let chargingOperatorRepository: any ChargingOperatorRepository
        if inMemory {
            chargingOperatorRepository = InMemoryChargingOperatorRepository()
        } else {
            do {
                let sqliteRepository = try SQLiteChargingOperatorRepository()
                try sqliteRepository.seedIfNeeded()
                chargingOperatorRepository = sqliteRepository
            } catch {
                #if DEBUG
                print("[Voltly] Operator SQLite acilamadi: \(error.localizedDescription). In-memory fallback kullaniliyor.")
                #endif
                TelemetryCenter.shared.crashReporter.record(
                    error: error,
                    additionalInfo: ["stage": "charging_operator_repository_init"]
                )
                let fallback = InMemoryChargingOperatorRepository()
                try? fallback.seedIfNeeded()
                chargingOperatorRepository = fallback
            }
        }

        return AppEnvironment(
            analytics: TelemetryCenter.shared.analytics,
            crashReporter: TelemetryCenter.shared.crashReporter,
            vehicleCatalog: StaticReferenceVehicleCatalog(),
            unplugReminderScheduler: {
                #if os(iOS)
                IOSUnplugReminderScheduler()
                #else
                NoopUnplugReminderScheduler()
                #endif
            }(),
            vehicleRepository: vehicleRepository,
            chargingSessionRepository: chargingRepository,
            settingsRepository: settingsRepository,
            goalRepository: resolvedGoalRepository,
            chargingOperatorRepository: chargingOperatorRepository,
            consumptionBlockRepository: consumptionBlockRepository,
            vehicleMetricSnapshotRepository: vehicleMetricSnapshotRepository,
            dailyInsightUserDefaults: dailyInsightUserDefaults,
            featureFlagUserDefaults: dailyInsightUserDefaults,
            dashboardCacheService: resolvedDashboardCacheService
        )
    }

    public static func bootstrap() throws -> AppEnvironment {
        do {
            return try live()
        } catch {
            TelemetryCenter.shared.crashReporter.record(
                error: error,
                additionalInfo: ["stage": "bootstrap_live"]
            )
            #if DEBUG
            print("[Voltly] Kalici veri acilamadi: \(error.localizedDescription)")
            print("[Voltly] Gecici bellek modu ile acilis deneniyor.")
            #endif
            do {
                return try live(inMemory: true)
            } catch {
                TelemetryCenter.shared.crashReporter.record(
                    error: error,
                    additionalInfo: ["stage": "bootstrap_fallback_inmemory"]
                )
                throw error
            }
        }
    }

    private static func makeIsolatedInMemoryUserDefaults() -> UserDefaults {
        let suiteName = "voltly.inmemory.daily-insight.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
