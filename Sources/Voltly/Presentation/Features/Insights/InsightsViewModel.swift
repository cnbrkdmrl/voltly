import Foundation

public struct MethodShare: Identifiable, Equatable {
    public let id = UUID()
    public let method: ChargeMethod
    public let costShare: Double
    public let energyShare: Double
    public let sessionShare: Double
}

public struct StationAverage: Identifiable, Equatable {
    public let id = UUID()
    public let station: String
    public let averageTLPerKWh: Double
    public let sessionCount: Int
    public let averageSpeedKW: Double?
}

public struct ChargeRecommendation: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let detail: String
}

public struct BehaviorInsightItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let iconName: String
    public let accent: ChargeMethod?
}

public struct CostAnalysisEntry: Equatable {
    public let location: String
    public let method: ChargeMethod
    public let tlPerKWh: Double
}

public struct CostAnalysisSummary: Equatable {
    public let cheapest: CostAnalysisEntry
    public let mostExpensive: CostAnalysisEntry
}

public struct OperatorPriceAverage: Identifiable, Equatable {
    public let id = UUID()
    public let operatorName: String
    public let averageTLPerKWh: Double
    public let sessionCount: Int
}

public struct ChargeHabitItem: Identifiable, Equatable {
    public let id = UUID()
    public let method: ChargeMethod
    public let percent: Double
    public let targetPercent: Double?
}

public struct ChargeHabitCTA: Equatable {
    public let title: String
    public let suggestedChargeType: SuggestedChargeDefaultType
}

public struct ChargeHabitSummary: Equatable {
    public let items: [ChargeHabitItem]
    public let headline: String
    public let recommendationText: String
    public let targetSummaryText: String?
    public let cta: ChargeHabitCTA?
}

public struct ChargeHabitMetricsSummary: Equatable {
    public let averageSOCStart: Double?
    public let averageSOCEnd: Double?
    public let averageDurationMin: Double?
    public let averageEnergyKWh: Double?
    public let rangeComment: String
    public let recommendedRangeText: String
    public let bestRangeInsight: String?
}

public struct VehicleEfficiencySummary: Equatable {
    public let averageEnergyPer100Km: MeasuredValue<Double>
    public let confidence: DataConfidenceScore
    public let headline: String
    public let supportingText: String
}

public struct SmartChargeSuggestion: Equatable {
    public let title: String
    public let message: String
    public let potentialSavings: Double
    public let comparedEnergyKWh: Double
    public let acAverageTLPerKWh: Double
    public let dcAverageTLPerKWh: Double
    public let currencyCode: String
}

public struct TLPerKWhTrendPoint: Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let averageTLPerKWh: Double
    public let sessionCount: Int
}

public struct MonthlyEVCostPoint: Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let totalCost: Double
    public let totalEnergyKWh: Double
    public let averageTLPerKWh: Double?
    public let sessionCount: Int
}

@MainActor
public final class InsightsViewModel: ObservableObject {
    private enum TrendConstants {
        static let trailingDays = 30
        static let anomalyWindowDays = 14
        static let trailingMonths = 12
    }

    private enum HabitTargets {
        static let maxPreferredDCRatio = 60.0
        static let minPreferredACRatio = 25.0
        static let recommendedStartLowerBound = 15.0
        static let recommendedStartUpperBound = 25.0
        static let recommendedEndLowerBound = 75.0
        static let recommendedEndUpperBound = 80.0
        static let healthyStartLowerBound = 10.0
        static let healthyStartUpperBound = 30.0
        static let healthyEndLowerBound = 75.0
        static let healthyEndUpperBound = 90.0
        static let idealWindowLowerBound = 35.0
        static let idealWindowUpperBound = 70.0
    }

    private enum EfficiencyLimits {
        static let minKWhPer100Km = 8.0
        static let maxKWhPer100Km = 40.0
        static let maxDistancePerSessionKM = 2_500.0
        static let maxDistancePerDayKM = 1_200.0
    }

    @Published public private(set) var hasActiveVehicle = false
    @Published public private(set) var totalSessionCount = 0
    @Published public private(set) var monthlySessionCount = 0
    @Published public private(set) var tlPerKWhTrend: [TLPerKWhTrendPoint] = []
    @Published public private(set) var tlPerKWhTrendCurrencyCode: String = AppConstants.defaultCurrencyCode
    @Published public private(set) var monthlyEVCostTrend: [MonthlyEVCostPoint] = []
    @Published public private(set) var monthlyEVCostCurrencyCode: String = AppConstants.defaultCurrencyCode
    @Published public private(set) var methodShares: [MethodShare] = []
    @Published public private(set) var stationAverages: [StationAverage] = []
    @Published public private(set) var fullChargeRate: Double = 0
    @Published public private(set) var vehicleEfficiencySummary: VehicleEfficiencySummary?
    @Published public private(set) var insightCards: [BehaviorInsightItem] = []
    @Published public private(set) var recommendations: [ChargeRecommendation] = []
    @Published public private(set) var temperatureInsight: String?
    @Published public private(set) var costAnalysis: CostAnalysisSummary?
    @Published public private(set) var dcOperatorAverages: [OperatorPriceAverage] = []
    @Published public private(set) var operatorAnalysisCurrencyCode: String = AppConstants.defaultCurrencyCode
    @Published public private(set) var advancedAnalysis: ChargeInsightReport?
    @Published public private(set) var recentSessionScores: [ChargeSessionScoreReport] = []
    @Published public private(set) var actionableInsight: ActionableAnalysisInsight?
    @Published public private(set) var dailyInsight: DailyInsightOutput?
    @Published public private(set) var retentionPrompt: InAppReminderMessage?
    @Published public private(set) var trendBreakInsight: TrendBreakInsight?
    @Published public private(set) var trendBreakInsights: [TrendBreakInsight] = []
    @Published public private(set) var contextInsights: [ChargeContextInsight] = []
    @Published public private(set) var goalProgressSnapshot: GoalProgressSnapshot?
    @Published public private(set) var personalRecords: [PersonalRecordItem] = []
    @Published public private(set) var chargeHabitSummary: ChargeHabitSummary?
    @Published public private(set) var chargeHabitMetricsSummary: ChargeHabitMetricsSummary?
    @Published public private(set) var smartChargeSuggestion: SmartChargeSuggestion?
    @Published public private(set) var smartFavoriteStationReport: SmartFavoriteStationReport?
    @Published public private(set) var userChargingProfile: UserChargingProfileReport?
    @Published public private(set) var experimentSuggestionReport: ExperimentSuggestionReport?
    @Published public private(set) var chargeHabitAnalysisConfidence: AnalysisConfidenceReport?
    @Published public private(set) var vehicleEfficiencyAnalysisConfidence: AnalysisConfidenceReport?
    @Published public private(set) var usageMode: UsageMode = .balanced
    @Published public private(set) var suggestedGoals: SuggestedGoalSet?
    @Published public private(set) var monthlyPlan: MonthlyPlan?
    @Published public private(set) var primaryBehaviorRecommendation: Recommendation?
    @Published public private(set) var supportingBehaviorRecommendations: [Recommendation] = []
    @Published public private(set) var smartRecommendationsEnabled = true
    @Published public private(set) var advancedInsightsEnabled = true
    @Published public private(set) var errorMessage: String?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
        refreshFeatureFlags()
    }

    public func makeRealEVCostViewModel() -> RealEVCostViewModel {
        RealEVCostViewModel(environment: environment)
    }

    public func makeSuggestedChargeViewModel() -> AddChargeViewModel? {
        guard let actionableInsight else { return nil }

        let viewModel = AddChargeViewModel(environment: environment)
        viewModel.applySuggestedDefaultChargeType(actionableInsight.suggestedAction.defaultChargeType)
        return viewModel
    }

    public func makeSuggestedChargeViewModel(
        defaultChargeType: SuggestedChargeDefaultType
    ) -> AddChargeViewModel {
        let viewModel = AddChargeViewModel(environment: environment)
        viewModel.applySuggestedDefaultChargeType(defaultChargeType)
        return viewModel
    }

    public func makeSuggestedChargeViewModel(
        stationSuggestion: SmartFavoriteStationSuggestion
    ) -> AddChargeViewModel {
        let viewModel = AddChargeViewModel(environment: environment)
        viewModel.applySmartFavoriteStation(stationSuggestion)
        return viewModel
    }

    public func refreshDailyInsightOnAppear(referenceDate: Date = .now) {
        guard smartRecommendationsEnabled else {
            dailyInsight = nil
            return
        }
        environment.dailyInsightCoordinator.refreshCandidate(referenceDate: referenceDate)
        dailyInsight = environment.dailyInsightCoordinator.consumeDisplayableInsight(referenceDate: referenceDate)
    }

    public func load(referenceDate: Date = .now) {
        do {
            refreshFeatureFlags()
            guard let vehicle = try environment.vehicleRepository.fetchActiveVehicle() else {
                resetForNoVehicle()
                return
            }

            hasActiveVehicle = true

            let allSessions = try environment.chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            let metricSnapshots = Dictionary(
                uniqueKeysWithValues: try environment.vehicleMetricSnapshotRepository
                    .fetchAll(vehicleID: vehicle.id)
                    .map { ($0.period, $0) }
            )
            let goals = try environment.goalRepository.fetchGoals()
            usageMode = environment.usageModeStore.loadUsageMode()
            totalSessionCount = allSessions.count
            retentionPrompt = environment.retentionPromptService.generatePrompt(
                sessions: allSessions,
                goals: goals,
                referenceDate: referenceDate
            )
            let computedAverageEnergyPer100Km = measuredAverageEnergyFromSavingsEngine(
                vehicle: vehicle,
                sessions: allSessions,
                referenceDate: referenceDate,
                snapshots: metricSnapshots
            )
            vehicleEfficiencySummary = buildVehicleEfficiencySummary(
                vehicle: vehicle,
                sessions: allSessions,
                measuredAverage: computedAverageEnergyPer100Km,
                snapshots: metricSnapshots
            )
            vehicleEfficiencyAnalysisConfidence = buildVehicleEfficiencyAnalysisConfidence(
                sessions: allSessions,
                vehicleEfficiencySummary: vehicleEfficiencySummary
            )
            tlPerKWhTrend = buildTLPerKWhTrend(from: allSessions, referenceDate: referenceDate)
            tlPerKWhTrendCurrencyCode = resolveTLPerKWhTrendCurrencyCode(from: allSessions)
            monthlyEVCostTrend = buildMonthlyEVCostTrend(from: allSessions, referenceDate: referenceDate)
            monthlyEVCostCurrencyCode = allSessions.first?.currencyCode ?? AppConstants.defaultCurrencyCode
            if advancedInsightsEnabled || smartRecommendationsEnabled {
                advancedAnalysis = environment.chargeInsightService.analyze(
                    vehicle: vehicle,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
                smartFavoriteStationReport = environment.smartFavoriteStationService.makeReport(
                    sessions: allSessions
                )
            } else {
                advancedAnalysis = nil
                smartFavoriteStationReport = nil
            }
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let savingsReport = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: allSessions,
                preferences: baseline,
                referenceDate: referenceDate
            )
            let activeSavingsSummary = savingsReport.thisMonth ?? savingsReport.last30Days
            suggestedGoals = environment.goalSuggestionEngine.suggest(
                input: GoalSuggestionInput(
                    usageMode: usageMode,
                    report: advancedAnalysis,
                    savingsReport: savingsReport,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
            )
            let recommendationConfidence = environment.confidenceScoreEngine.evaluate(
                ConfidenceScoreInput(
                    sampleCount: advancedAnalysis?.overall.sessionCount ?? allSessions.count,
                    dataConfidence: advancedAnalysis?.overall.averageTLPer100Km.confidence,
                    hasCostData: activeSavingsSummary?.costPerKWh != nil || !allSessions.isEmpty,
                    hasDistanceData: activeSavingsSummary?.estimatedDistanceKm ?? 0 > 0
                )
            )
            let basePlan = environment.monthlyPlanEngine.buildPlan(
                MonthlyPlanInput(
                    usageMode: usageMode,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    report: advancedAnalysis,
                    savingsSummary: activeSavingsSummary,
                    sessions: allSessions,
                    referenceDate: referenceDate
                ),
                confidence: recommendationConfidence
            )
            monthlyPlan = environment.habitProgressEngine.evaluate(
                PlanProgressInput(
                    plan: basePlan,
                    report: advancedAnalysis,
                    savingsSummary: activeSavingsSummary,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
            )
            let behaviorRecommendations = environment.recommendationEngine.buildRecommendations(
                RecommendationInput(
                    usageMode: usageMode,
                    report: advancedAnalysis,
                    savingsSummary: activeSavingsSummary,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    referenceDate: referenceDate
                )
            )
            primaryBehaviorRecommendation = behaviorRecommendations.first
            supportingBehaviorRecommendations = Array(behaviorRecommendations.dropFirst().prefix(2))
            if let advancedAnalysis {
                userChargingProfile = environment.userChargingProfileService.makeProfile(
                    report: advancedAnalysis,
                    referenceDate: referenceDate
                )
            } else {
                userChargingProfile = nil
            }
            experimentSuggestionReport = smartRecommendationsEnabled
                ? buildExperimentSuggestionReport(
                    report: advancedAnalysis,
                    profile: userChargingProfile,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
                : nil
            personalRecords = advancedInsightsEnabled
                ? environment.personalRecordsService.generateRecords(
                    vehicle: vehicle,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
                : []
            contextInsights = advancedInsightsEnabled
                ? environment.chargeContextInsightService.generateInsights(from: allSessions)
                : []
            if smartRecommendationsEnabled {
                let currentAnomalyWindowSessions = sessionsInPastDays(
                    allSessions,
                    days: TrendConstants.anomalyWindowDays,
                    endingAt: referenceDate
                )
                let previousAnomalyWindowSessions = sessionsInPreviousWindow(
                    allSessions,
                    days: TrendConstants.anomalyWindowDays,
                    referenceDate: referenceDate
                )
                let trendBreakResult = environment.trendBreakDetectionService.detect(
                    input: TrendBreakDetectionInput(
                        recentSessions: currentAnomalyWindowSessions,
                        baselineSessions: previousAnomalyWindowSessions,
                        referenceDate: referenceDate
                    )
                )
                trendBreakInsight = trendBreakResult.primaryInsight
                trendBreakInsights = trendBreakResult.insights
            } else {
                trendBreakInsight = nil
                trendBreakInsights = []
            }
            if advancedInsightsEnabled {
                refreshActionableInsight(from: advancedAnalysis)
            } else {
                actionableInsight = nil
            }
            recentSessionScores = allSessions
                .sorted { $0.sessionDate > $1.sessionDate }
                .prefix(3)
                .map {
                    environment.chargeSessionScoringService.score(
                        session: $0,
                        vehicle: vehicle,
                        history: allSessions
                    )
                }

            let sessions = try environment.chargingSessionRepository.fetchInRange(
                vehicleID: vehicle.id,
                from: referenceDate.startOfMonth,
                to: referenceDate.endOfMonth
            )
            goalProgressSnapshot = environment.goalProgressService.makeSnapshot(
                goals: goals,
                monthlySessions: sessions,
                currencyCode: allSessions.first?.currencyCode ?? AppConstants.defaultCurrencyCode
            )

            monthlySessionCount = sessions.count

            guard !sessions.isEmpty else {
                resetForNoSession(
                    advancedAnalysis: advancedAnalysis,
                    recentSessionScores: recentSessionScores,
                    goalProgressSnapshot: goalProgressSnapshot,
                    vehicle: vehicle,
                    allSessions: allSessions,
                    referenceDate: referenceDate,
                    metricSnapshots: metricSnapshots
                )
                return
            }

            methodShares = buildMethodShares(from: sessions)
            stationAverages = buildStationAverages(from: sessions)
            fullChargeRate = (Double(sessions.filter { $0.isFullCharge }.count) / Double(sessions.count)) * 100
            insightCards = buildInsights(
                from: sessions,
                shares: methodShares,
                advancedAnalysis: advancedAnalysis,
                excludingActionInsightIDs: duplicatedActionInsightIDs(for: actionableInsight)
            )
            recommendations = buildRecommendations(from: sessions)
            temperatureInsight = buildTemperatureInsight(from: sessions)
            costAnalysis = buildCostAnalysis(from: sessions)
            dcOperatorAverages = buildDCOperatorAverages(from: sessions)
            operatorAnalysisCurrencyCode = sessions.first?.currencyCode ?? AppConstants.defaultCurrencyCode
            if advancedInsightsEnabled, let advancedAnalysis {
                chargeHabitSummary = buildChargeHabitSummary(
                    from: advancedAnalysis,
                    sessions: allSessions
                )
                chargeHabitMetricsSummary = buildChargeHabitMetricsSummary(
                    from: advancedAnalysis,
                    vehicle: vehicle,
                    sessions: allSessions
                )
            } else {
                chargeHabitSummary = nil
                chargeHabitAnalysisConfidence = nil
                chargeHabitMetricsSummary = nil
            }
            smartChargeSuggestion = smartRecommendationsEnabled
                ? buildSmartChargeSuggestion(from: sessions)
                : nil
        } catch {
            tlPerKWhTrend = []
            tlPerKWhTrendCurrencyCode = AppConstants.defaultCurrencyCode
            monthlyEVCostTrend = []
            monthlyEVCostCurrencyCode = AppConstants.defaultCurrencyCode
            advancedAnalysis = nil
            actionableInsight = nil
            dailyInsight = nil
            retentionPrompt = nil
            trendBreakInsight = nil
            trendBreakInsights = []
            contextInsights = []
            goalProgressSnapshot = nil
            personalRecords = []
            vehicleEfficiencySummary = nil
            smartFavoriteStationReport = nil
            userChargingProfile = nil
            experimentSuggestionReport = nil
            chargeHabitAnalysisConfidence = nil
            vehicleEfficiencyAnalysisConfidence = nil
            suggestedGoals = nil
            monthlyPlan = nil
            primaryBehaviorRecommendation = nil
            supportingBehaviorRecommendations = []
            errorMessage = error.localizedDescription
        }
    }

    private func refreshFeatureFlags() {
        smartRecommendationsEnabled = environment.featureAccessChecker.isEnabled(.smartRecommendations)
        advancedInsightsEnabled = environment.featureAccessChecker.isEnabled(.advancedInsights)
    }

    private func resetForNoVehicle() {
        hasActiveVehicle = false
        totalSessionCount = 0
        monthlySessionCount = 0
        tlPerKWhTrend = []
        tlPerKWhTrendCurrencyCode = AppConstants.defaultCurrencyCode
        monthlyEVCostTrend = []
        monthlyEVCostCurrencyCode = AppConstants.defaultCurrencyCode
        methodShares = []
        stationAverages = []
        fullChargeRate = 0
        vehicleEfficiencySummary = nil
        insightCards = []
        recommendations = []
        temperatureInsight = nil
        costAnalysis = nil
        dcOperatorAverages = []
        operatorAnalysisCurrencyCode = AppConstants.defaultCurrencyCode
        advancedAnalysis = nil
        recentSessionScores = []
        actionableInsight = nil
        dailyInsight = nil
        retentionPrompt = nil
        trendBreakInsight = nil
        trendBreakInsights = []
        contextInsights = []
        goalProgressSnapshot = nil
        personalRecords = []
        chargeHabitSummary = nil
        chargeHabitMetricsSummary = nil
        smartChargeSuggestion = nil
        smartFavoriteStationReport = nil
        userChargingProfile = nil
        experimentSuggestionReport = nil
        chargeHabitAnalysisConfidence = nil
        vehicleEfficiencyAnalysisConfidence = nil
        suggestedGoals = nil
        monthlyPlan = nil
        primaryBehaviorRecommendation = nil
        supportingBehaviorRecommendations = []
    }

    private func resetForNoSession(
        advancedAnalysis: ChargeInsightReport?,
        recentSessionScores: [ChargeSessionScoreReport],
        goalProgressSnapshot: GoalProgressSnapshot?,
        vehicle: Vehicle,
        allSessions: [ChargingSession],
        referenceDate: Date,
        metricSnapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot]
    ) {
        methodShares = []
        stationAverages = []
        fullChargeRate = 0
        let computedAverageEnergyPer100Km = measuredAverageEnergyFromSavingsEngine(
            vehicle: vehicle,
            sessions: allSessions,
            referenceDate: referenceDate,
            snapshots: metricSnapshots
        )
        vehicleEfficiencySummary = buildVehicleEfficiencySummary(
            vehicle: vehicle,
            sessions: allSessions,
            measuredAverage: computedAverageEnergyPer100Km,
            snapshots: metricSnapshots
        )
        vehicleEfficiencyAnalysisConfidence = buildVehicleEfficiencyAnalysisConfidence(
            sessions: allSessions,
            vehicleEfficiencySummary: vehicleEfficiencySummary
        )
        if let advancedAnalysis, !advancedAnalysis.actionInsights.isEmpty {
            let hiddenActionInsightIDs = duplicatedActionInsightIDs(for: actionableInsight)
            insightCards = advancedAnalysis.actionInsights
                .filter { !hiddenActionInsightIDs.contains($0.id) }
                .map {
                    BehaviorInsightItem(
                        title: $0.title,
                        detail: $0.detail,
                        iconName: "sparkles",
                        accent: nil
                    )
                }
        } else {
            insightCards = [
                BehaviorInsightItem(
                    title: "İçgörü hazır değil",
                    detail: "Bu ay analiz oluşması için en az 1 şarj seansı kaydet.",
                    iconName: "sparkles",
                    accent: .publicAC
                )
            ]
        }
        recommendations = []
        temperatureInsight = nil
        costAnalysis = nil
        dcOperatorAverages = []
        operatorAnalysisCurrencyCode = AppConstants.defaultCurrencyCode
        self.advancedAnalysis = advancedAnalysis
        self.recentSessionScores = recentSessionScores
        self.goalProgressSnapshot = goalProgressSnapshot
        refreshActionableInsight(from: advancedAnalysis)
        trendBreakInsight = nil
        trendBreakInsights = []
        if let advancedAnalysis {
            chargeHabitSummary = buildChargeHabitSummary(
                from: advancedAnalysis,
                sessions: allSessions
            )
            chargeHabitMetricsSummary = buildChargeHabitMetricsSummary(
                from: advancedAnalysis,
                vehicle: vehicle,
                sessions: allSessions
            )
        } else {
            chargeHabitSummary = nil
            chargeHabitAnalysisConfidence = nil
            chargeHabitMetricsSummary = nil
        }
        smartChargeSuggestion = nil
        smartFavoriteStationReport = environment.smartFavoriteStationService.makeReport(
            sessions: allSessions
        )
        if let advancedAnalysis {
            userChargingProfile = environment.userChargingProfileService.makeProfile(
                report: advancedAnalysis,
                referenceDate: advancedAnalysis.generatedAt
            )
        } else {
            userChargingProfile = nil
        }
        experimentSuggestionReport = buildExperimentSuggestionReport(
            report: advancedAnalysis,
            profile: userChargingProfile,
            sessions: allSessions,
            referenceDate: advancedAnalysis?.generatedAt ?? .now
        )
        dailyInsight = nil
        retentionPrompt = nil
    }

    private func measuredAverageEnergyFromSavingsEngine(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        referenceDate: Date,
        snapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot] = [:]
    ) -> MeasuredValue<Double>? {
        if let snapshot = snapshots[.last365Days] ?? snapshots[.allTime],
           let avgKWh100Km = snapshot.avgKWh100Km {
            let isExact = snapshot.basisLabel == ConsumptionBlockConfidenceType.real.basisLabel
            return isExact ? .exact(avgKWh100Km) : .estimated(avgKWh100Km)
        }
        guard !sessions.isEmpty else { return nil }
        do {
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let report = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: sessions,
                preferences: baseline,
                referenceDate: referenceDate
            )
            guard let summary = report.last12Months ?? report.allTime else { return nil }
            let isExact = summary.calculationMode.distance == .odometer
                && summary.calculationMode.consumption == .realData
            return isExact ? .exact(summary.avgConsumptionKWh100km) : .estimated(summary.avgConsumptionKWh100km)
        } catch {
            return environment.calculateEnergyPer100KmUseCase.execute(sessions: sessions)
        }
    }

    private func sessionsInPastDays(
        _ sessions: [ChargingSession],
        days: Int,
        endingAt referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)

        return sessions.filter { $0.sessionDate >= start && $0.sessionDate <= referenceDate }
    }

    private func sessionsInPreviousWindow(
        _ sessions: [ChargingSession],
        days: Int,
        referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let currentWindowStart = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)
        let previousWindowEnd = currentWindowStart.addingTimeInterval(-1)
        let previousWindowStart = calendar.date(
            byAdding: .day,
            value: -days,
            to: currentWindowStart
        ) ?? currentWindowStart

        return sessions.filter {
            $0.sessionDate >= previousWindowStart && $0.sessionDate <= previousWindowEnd
        }
    }

    private func refreshActionableInsight(from report: ChargeInsightReport?) {
        guard let report,
              report.overall.sessionCount > 0 else {
            actionableInsight = nil
            return
        }

        let next = environment.generateActionableInsightsSkill.generateInsight(
            input: GenerateActionableInsightsInput(
                dcUsageRatio: report.usageRatios.dcRatio.value,
                acUsageRatio: report.usageRatios.acRatio.value,
                homeUsageRatio: report.usageRatios.homeRatio.value,
                averageChargeRange: averageChargeRange(from: report)
            )
        )

        guard actionableInsight != next else { return }
        actionableInsight = next
    }

    private func averageChargeRange(from report: ChargeInsightReport) -> Double? {
        let preferredWindow = report.lastThirtyDays.sessionCount > 0 ? report.lastThirtyDays : report.overall
        guard let start = preferredWindow.averageStartSOC.value,
              let end = preferredWindow.averageEndSOC.value,
              end > start else {
            return nil
        }
        return end - start
    }

    private func duplicatedActionInsightIDs(
        for actionableInsight: ActionableAnalysisInsight?
    ) -> Set<String> {
        guard let actionableInsight else { return [] }

        switch actionableInsight.recommendationType {
        case .reduceDC:
            return ["dc-heavy"]
        case .increaseAC:
            return []
        case .optimizeRange:
            return []
        }
    }

    private func buildMethodShares(from sessions: [ChargingSession]) -> [MethodShare] {
        let totalCost = sessions.reduce(0) { $0 + $1.priceTotal }
        let totalEnergy = sessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let totalCount = Double(sessions.count)

        return ChargeMethod.allCases.map { method in
            let subset = sessions.filter { $0.chargeMethod == method }
            let subsetCost = subset.reduce(0) { $0 + $1.priceTotal }
            let subsetEnergy = subset.reduce(0) { $0 + ($1.energyKWh ?? 0) }

            return MethodShare(
                method: method,
                costShare: totalCost > 0 ? (subsetCost / totalCost) * 100 : 0,
                energyShare: totalEnergy > 0 ? (subsetEnergy / totalEnergy) * 100 : 0,
                sessionShare: totalCount > 0 ? (Double(subset.count) / totalCount) * 100 : 0
            )
        }
    }

    private func buildStationAverages(from sessions: [ChargingSession]) -> [StationAverage] {
        let grouped = Dictionary(grouping: sessions, by: \.stationDisplayName)

        return grouped.compactMap { station, groupedSessions in
            let energySessions = groupedSessions.filter { ($0.energyKWh ?? 0) > 0 }
            let totalEnergy = energySessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalCost = energySessions.reduce(0) { $0 + $1.priceTotal }
            guard totalEnergy > 0 else { return nil }

            let speedSessions = groupedSessions.filter {
                ($0.energyKWh ?? 0) > 0 && ($0.durationMin ?? 0) > 0
            }
            let totalSpeedEnergy = speedSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalSpeedHours = speedSessions.reduce(0.0) { partial, session in
                partial + (Double(session.durationMin ?? 0) / 60.0)
            }
            let averageSpeedKW: Double?
            if totalSpeedEnergy > 0, totalSpeedHours > 0 {
                averageSpeedKW = totalSpeedEnergy / totalSpeedHours
            } else {
                averageSpeedKW = nil
            }

            return StationAverage(
                station: station,
                averageTLPerKWh: totalCost / totalEnergy,
                sessionCount: groupedSessions.count,
                averageSpeedKW: averageSpeedKW
            )
        }
        .sorted { $0.averageTLPerKWh < $1.averageTLPerKWh }
    }

    private func buildInsights(
        from sessions: [ChargingSession],
        shares: [MethodShare],
        advancedAnalysis: ChargeInsightReport?,
        excludingActionInsightIDs hiddenActionInsightIDs: Set<String>
    ) -> [BehaviorInsightItem] {
        var items: [BehaviorInsightItem] = []

        if let advancedAnalysis {
            items.append(
                contentsOf: advancedAnalysis.actionInsights
                    .filter { !hiddenActionInsightIDs.contains($0.id) }
                    .map { insight in
                        BehaviorInsightItem(
                            title: insight.title,
                            detail: insight.detail,
                            iconName: "sparkles",
                            accent: nil
                        )
                    }
            )
        }

        if let dcShare = shares.first(where: { $0.method == .publicDC }),
           dcShare.costShare >= 60,
           dcShare.energyShare <= 40 {
            items.append(
                BehaviorInsightItem(
                    title: "Tasarruf önerisi",
                    detail: "Harcamanın %\(Int(dcShare.costShare)) kısmı DC'de. Enerji payı %\(Int(dcShare.energyShare)); Ev/AC dengelemesi maliyeti düşürebilir.",
                    iconName: "lightbulb.max.fill",
                    accent: .publicDC
                )
            )
        }

        let dcSessions = sessions.filter { $0.chargeMethod == .publicDC && ($0.energyKWh ?? 0) > 0 }
        let nonDCSessions = sessions.filter { $0.chargeMethod != .publicDC && ($0.energyKWh ?? 0) > 0 }

        let dcEnergy = dcSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let dcCost = dcSessions.reduce(0) { $0 + $1.priceTotal }
        let nonDCEnergy = nonDCSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let nonDCCost = nonDCSessions.reduce(0) { $0 + $1.priceTotal }

        if dcEnergy > 0, nonDCEnergy > 0 {
            let dcTLPerKWh = dcCost / dcEnergy
            let altTLPerKWh = nonDCCost / nonDCEnergy
            if dcTLPerKWh > altTLPerKWh {
                let potential = (dcTLPerKWh - altTLPerKWh) * dcEnergy
                if potential > 0 {
                    items.append(
                        BehaviorInsightItem(
                            title: "Maliyet fırsatı",
                            detail: "DC yerine Ev/AC ağırlıklı kullanım ile bu ay yaklaşık \(Int(potential.rounded())) TL daha az ödeyebilirdin.",
                            iconName: "arrow.down.circle.fill",
                            accent: .home
                        )
                    )
                }
            }
        }

        if let bestStation = stationAverages.first {
            items.append(
                BehaviorInsightItem(
                    title: "En iyi maliyet noktası",
                    detail: "\(bestStation.station) ortalama \(NumberFormatting.oneDecimal(bestStation.averageTLPerKWh)) TL/kWh ile en avantajlı istasyon.",
                    iconName: "rosette",
                    accent: .publicAC
                )
            )
        }

        let compacted = deduplicatedInsights(items)
        return Array(compacted.prefix(3))
    }

    private func buildRecommendations(from sessions: [ChargingSession]) -> [ChargeRecommendation] {
        var items: [ChargeRecommendation] = []

        if let cheapest = stationAverages.first {
            items.append(
                ChargeRecommendation(
                    title: "En ekonomik istasyon",
                    detail: "\(cheapest.station) ortalama \(NumberFormatting.oneDecimal(cheapest.averageTLPerKWh)) TL/kWh"
                )
            )
        }

        let speedCandidates: [(name: String, speed: Double)] = Dictionary(grouping: sessions) { session in
            if let location = session.locationName, !location.isEmpty { return location }
            if let station = session.stationBrand, !station.isEmpty { return station }
            return "Bilinmeyen Istasyon"
        }
        .compactMap { key, groupedSessions in
            let valid = groupedSessions.filter {
                ($0.energyKWh ?? 0) > 0 && ($0.durationMin ?? 0) > 0
            }
            guard !valid.isEmpty else { return nil }

            let totalEnergy = valid.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalHours = valid.reduce(0.0) { $0 + (Double($1.durationMin ?? 0) / 60.0) }
            guard totalHours > 0 else { return nil }

            return (name: key, speed: totalEnergy / totalHours)
        }

        if let fastest = speedCandidates.max(by: { $0.speed < $1.speed }) {
            items.append(
                ChargeRecommendation(
                    title: "En hızlı nokta",
                    detail: "\(fastest.name) ortalama \(NumberFormatting.oneDecimal(fastest.speed)) kW eşdeğer hız"
                )
            )
        }

        let dcByLocation = Dictionary(grouping: sessions.filter { $0.chargeMethod == .publicDC }) { session in
            if let location = session.locationName, !location.isEmpty { return location }
            if let station = session.stationBrand, !station.isEmpty { return station }
            return "Bilinmeyen Istasyon"
        }

        let bestDC = dcByLocation.compactMap { key, grouped -> (String, Double)? in
            let valid = grouped.filter { ($0.energyKWh ?? 0) > 0 }
            let totalEnergy = valid.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalCost = valid.reduce(0) { $0 + $1.priceTotal }
            guard totalEnergy > 0 else { return nil }
            return (key, totalCost / totalEnergy)
        }
        .sorted { $0.1 < $1.1 }
        .first

        if let bestDC {
            items.append(
                ChargeRecommendation(
                    title: "DC önerisi",
                    detail: "DC gerekiyorsa kayıtlarına göre en iyi değer: \(bestDC.0)"
                )
            )
        }

        if let frequentLocation = mostFrequentLocation(from: sessions) {
            items.append(
                ChargeRecommendation(
                    title: "Konum odaklı öneri",
                    detail: "En sık şarj ettiğin bölge: \(frequentLocation). Bu bölgedeki maliyetleri önce karşılaştır."
                )
            )
        }

        return Array(items.prefix(4))
    }

    private func mostFrequentLocation(from sessions: [ChargingSession]) -> String? {
        let names = sessions.compactMap {
            if let location = $0.locationName, !location.isEmpty { return location }
            if let station = $0.stationBrand, !station.isEmpty { return station }
            return nil
        }
        let grouped = Dictionary(grouping: names, by: { $0 })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    private func buildTemperatureInsight(from sessions: [ChargingSession]) -> String? {
        let valid = sessions.filter { $0.outsideTempC != nil && ($0.energyKWh ?? 0) > 0 }
        guard valid.count >= 3 else { return nil }

        let cold = valid.filter { ($0.outsideTempC ?? 0) < 10 }
        let mild = valid.filter { ($0.outsideTempC ?? 0) >= 20 }

        guard !cold.isEmpty, !mild.isEmpty else { return nil }

        let coldTLPerKWh = averageTLPerKWh(of: cold)
        let mildTLPerKWh = averageTLPerKWh(of: mild)

        guard let coldTLPerKWh, let mildTLPerKWh, mildTLPerKWh > 0 else { return nil }

        let change = ((coldTLPerKWh - mildTLPerKWh) / mildTLPerKWh) * 100
        if change > 0 {
            return "Soğuk havada (10°C altı) birim enerji maliyeti sıcak günlere göre yaklaşık %\(Int(change.rounded())) daha yüksek görünüyor."
        }

        return "Sıcaklık kaynaklı belirgin bir maliyet artışı bu ay gözlenmedi."
    }

    private func deduplicatedInsights(_ items: [BehaviorInsightItem]) -> [BehaviorInsightItem] {
        var seenDetails = Set<String>()
        var seenTopics = Set<String>()
        var unique: [BehaviorInsightItem] = []

        for item in items {
            let normalizedDetail = normalizeInsightText("\(item.title) \(item.detail)")
            let topicKey = insightTopicKey(for: normalizedDetail)

            guard seenDetails.insert(normalizedDetail).inserted else { continue }
            if let topicKey,
               !seenTopics.insert(topicKey).inserted {
                continue
            }

            unique.append(item)
        }

        return unique
    }

    private func normalizeInsightText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func insightTopicKey(for normalizedText: String) -> String? {
        if normalizedText.contains("dc") {
            return "dc"
        }
        if normalizedText.contains("maliyet") || normalizedText.contains("tasarruf") {
            return "cost"
        }
        if normalizedText.contains("istasyon") {
            return "station"
        }
        return nil
    }

    private func averageTLPerKWh(of sessions: [ChargingSession]) -> Double? {
        let totalEnergy = sessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let totalCost = sessions.reduce(0) { $0 + $1.priceTotal }
        guard totalEnergy > 0 else { return nil }
        return totalCost / totalEnergy
    }

    private func buildCostAnalysis(from sessions: [ChargingSession]) -> CostAnalysisSummary? {
        let entries: [CostAnalysisEntry] = sessions.compactMap { session in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return CostAnalysisEntry(
                location: session.stationDisplayName,
                method: session.chargeMethod,
                tlPerKWh: session.priceTotal / energy
            )
        }

        guard let cheapest = entries.min(by: { $0.tlPerKWh < $1.tlPerKWh }),
              let mostExpensive = entries.max(by: { $0.tlPerKWh < $1.tlPerKWh }) else {
            return nil
        }

        return CostAnalysisSummary(cheapest: cheapest, mostExpensive: mostExpensive)
    }

    private func buildChargeHabitSummary(
        from report: ChargeInsightReport,
        sessions: [ChargingSession]
    ) -> ChargeHabitSummary {
        let items = [
            ChargeHabitItem(method: .home, percent: report.usageRatios.homeRatio.value ?? 0, targetPercent: nil),
            ChargeHabitItem(
                method: .publicAC,
                percent: report.usageRatios.acRatio.value ?? 0,
                targetPercent: (report.usageRatios.acRatio.value ?? 0) < HabitTargets.minPreferredACRatio ? HabitTargets.minPreferredACRatio : nil
            ),
            ChargeHabitItem(
                method: .publicDC,
                percent: report.usageRatios.dcRatio.value ?? 0,
                targetPercent: (report.usageRatios.dcRatio.value ?? 0) > HabitTargets.maxPreferredDCRatio ? HabitTargets.maxPreferredDCRatio : nil
            )
        ]
        let suggestion = actionableInsight?.suggestedAction.defaultChargeType
        chargeHabitAnalysisConfidence = buildChargeHabitAnalysisConfidence(
            report: report,
            sessions: sessions
        )

        return ChargeHabitSummary(
            items: items,
            headline: buildChargeHabitHeadline(for: actionableInsight),
            recommendationText: buildChargeHabitRecommendation(
                items: items,
                actionableInsight: actionableInsight,
                suggestedChargeType: suggestion
            ),
            targetSummaryText: buildChargeHabitTargetSummary(
                items: items,
                actionableInsight: actionableInsight
            ),
            cta: suggestion.map {
                ChargeHabitCTA(
                    title: "Planı uygula",
                    suggestedChargeType: $0
                )
            }
        )
    }

    private func buildChargeHabitAnalysisConfidence(
        report: ChargeInsightReport,
        sessions: [ChargingSession]
    ) -> AnalysisConfidenceReport? {
        let mergedConfidence = mergeConfidence([
            report.usageRatios.homeRatio.confidence,
            report.usageRatios.acRatio.confidence,
            report.usageRatios.dcRatio.confidence,
            report.overall.averageStartSOC.confidence,
            report.overall.averageEndSOC.confidence
        ])

        return environment.analysisConfidenceService.evaluate(
            context: .chargeHabit,
            sessions: sessions,
            primaryMetricConfidence: mergedConfidence
        )
    }

    private func buildVehicleEfficiencyAnalysisConfidence(
        sessions: [ChargingSession],
        vehicleEfficiencySummary: VehicleEfficiencySummary?
    ) -> AnalysisConfidenceReport? {
        environment.analysisConfidenceService.evaluate(
            context: .vehicleEfficiency,
            sessions: sessions,
            primaryMetricConfidence: vehicleEfficiencySummary?.confidence
        )
    }

    private func buildChargeHabitMetricsSummary(
        from report: ChargeInsightReport,
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> ChargeHabitMetricsSummary? {
        let averageSOCStart = report.overall.averageStartSOC.value
        let averageSOCEnd = report.overall.averageEndSOC.value
        let averageDurationMin = report.overall.averageDurationMinutes.value
        let averageEnergyKWh = report.overall.averageEnergyKWh.value

        guard averageSOCStart != nil || averageDurationMin != nil || averageEnergyKWh != nil else {
            return nil
        }

        return ChargeHabitMetricsSummary(
            averageSOCStart: averageSOCStart,
            averageSOCEnd: averageSOCEnd,
            averageDurationMin: averageDurationMin,
            averageEnergyKWh: averageEnergyKWh,
            rangeComment: buildChargeRangeComment(start: averageSOCStart, end: averageSOCEnd),
            recommendedRangeText: "Verimli pencere çoğu kullanımda yaklaşık %15-%80 bandında kalıyor.",
            bestRangeInsight: buildBestRangeInsight(vehicle: vehicle, sessions: sessions)
        )
    }

    private func buildChargeHabitHeadline(
        for actionableInsight: ActionableAnalysisInsight?
    ) -> String {
        switch actionableInsight?.recommendationType {
        case .reduceDC:
            return "DC payin maliyeti yukari cekiyor"
        case .increaseAC:
            return "AC payin duzenli avantaj uretmiyor"
        case .optimizeRange:
            return "Sarj penceren geregenden genis"
        case .none:
            return "Sarj dengende net bir sorun gorunmuyor"
        }
    }

    private func buildChargeHabitRecommendation(
        items: [ChargeHabitItem],
        actionableInsight: ActionableAnalysisInsight?,
        suggestedChargeType: SuggestedChargeDefaultType?
    ) -> String {
        if let actionableInsight, let suggestedChargeType {
            let methodTitle = suggestedChargeType.chargeMethod.titleTR
            switch actionableInsight.recommendationType {
            case .reduceDC:
                return "DC kullanimin agir basiyor. Siradaki seansi \(methodTitle) secmek birim maliyeti daha dengeli tutabilir."
            case .increaseAC:
                return "AC kullanimin sinirda kalmis. Siradaki plani \(methodTitle) agirlikli kurmak maliyet ritmini iyilestirebilir."
            case .optimizeRange:
                return "Uzun pencereyle sarj ediyorsun. Siradaki seansi \(methodTitle) ile daha dar aralikta planlamak sureyi ve maliyeti toparlayabilir."
            }
        }

        let homeShare = items.first(where: { $0.method == .home })?.percent ?? 0
        let acShare = items.first(where: { $0.method == .publicAC })?.percent ?? 0
        if homeShare + acShare >= 40 {
            return "Ev ve AC dengesi iyi gidiyor. Bu rutini korursan maliyet tarafinda stabil kalirsin."
        }

        return "Dagilimin dengeli gorunuyor. Duzenli AC veya Ev seanslari maliyeti sakin tutmaya devam eder."
    }

    private func buildChargeHabitTargetSummary(
        items: [ChargeHabitItem],
        actionableInsight: ActionableAnalysisInsight?
    ) -> String? {
        guard let actionableInsight else { return nil }

        switch actionableInsight.recommendationType {
        case .reduceDC:
            guard let dcItem = items.first(where: { $0.method == .publicDC }),
                  let target = dcItem.targetPercent else {
                return nil
            }
            return "DC %\(Int(dcItem.percent.rounded())), hedef %\(Int(target.rounded()))"
        case .increaseAC:
            guard let acItem = items.first(where: { $0.method == .publicAC }),
                  let target = acItem.targetPercent else {
                return nil
            }
            return "AC %\(Int(acItem.percent.rounded())), hedef en az %\(Int(target.rounded()))"
        case .optimizeRange:
            return nil
        }
    }

    private func buildChargeRangeComment(start: Double?, end: Double?) -> String {
        guard let start, let end, end > start else {
            return "Yuzde araligi netlestikce burada daha iyi yonlendirme goreceksin."
        }

        let window = end - start
        let startHealthy = (HabitTargets.healthyStartLowerBound...HabitTargets.healthyStartUpperBound).contains(start)
        let endHealthy = (HabitTargets.healthyEndLowerBound...HabitTargets.healthyEndUpperBound).contains(end)
        let windowHealthy = (HabitTargets.idealWindowLowerBound...HabitTargets.idealWindowUpperBound).contains(window)

        if startHealthy && endHealthy && windowHealthy {
            return "Mevcut araligin saglikli. Bataryayi gereksiz zorlamadan tutarli bir pencere kullaniyorsun."
        }
        if end > HabitTargets.healthyEndUpperBound {
            return "Sarji sikca ust yuzdelere tasiyorsun. %75-%80 civari bitis genelde daha verimli kalir."
        }
        if start < HabitTargets.healthyStartLowerBound {
            return "Seanslarin cok dusuk pil seviyesinden basliyor. %15-%25 bandi daha sakin bir baslangic verir."
        }
        if window > HabitTargets.idealWindowUpperBound {
            return "Sarj penceren genis. Daha dar bir aralik secmek sure ve maliyet tarafini duzenleyebilir."
        }

        return "Araligin kabul edilebilir. Bir miktar daha dar pencereyle verimi daha kolay koruyabilirsin."
    }

    private func buildBestRangeInsight(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> String? {
        let candidates = bestRangeCandidates(vehicle: vehicle, sessions: sessions)
        guard candidates.count >= 3 else { return nil }

        let topCount = max(1, Int(ceil(Double(candidates.count) * 0.3)))
        let bestSlice = Array(candidates.sorted { $0.rankingValue < $1.rankingValue }.prefix(topCount))
        guard let medianStart = median(of: bestSlice.map(\.startSOC)),
              let medianEnd = median(of: bestSlice.map(\.endSOC)) else {
            return nil
        }

        return "En verimli sarj araligin genelde %\(Int(medianStart.rounded()))-%\(Int(medianEnd.rounded())) bandinda toparlaniyor."
    }

    private func buildVehicleEfficiencySummary(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        measuredAverage: MeasuredValue<Double>?,
        snapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot] = [:]
    ) -> VehicleEfficiencySummary? {
        if let snapshotSummary = buildVehicleEfficiencySummary(from: snapshots) {
            return snapshotSummary
        }

        let diagnostics = odometerChainDiagnostics(from: sessions)
        if let measuredAverage,
           isPlausibleConsumption(measuredAverage.value),
           diagnostics.validTransitionCount > 0 {
            let source: AnalysisDataSourceKind = measuredAverage.isEstimated ? .mixed : .real
            return VehicleEfficiencySummary(
                averageEnergyPer100Km: measuredAverage,
                confidence: makeConfidence(
                    source: source,
                    sampleCount: diagnostics.validTransitionCount + 1,
                    exactSampleCount: measuredAverage.isEstimated ? diagnostics.validTransitionCount : diagnostics.validTransitionCount + 1,
                    estimatedSampleCount: measuredAverage.isEstimated ? 1 : 0,
                    missingSampleCount: max(sessions.count - (diagnostics.validTransitionCount + 1), 0)
                ),
                headline: measuredAverage.isEstimated
                    ? "Tuketim gorunumu km zinciriyle tahmini hesaplandi"
                    : "Tuketim gorunumun gercek surus verinle hizali",
                supportingText: measuredAverage.isEstimated
                    ? diagnostics.invalidTransitionCount > 0
                        ? "Km zincirinde bazi supheli gecisler filtrelendi. Kalan gecerli bloklarla tahmini ama anlamli bir gorunum olusturuldu."
                        : "Enerji verilerinin bir kismi tahmini olsa da kWh/100 km sonucu tutarli gorunuyor."
                    : diagnostics.invalidTransitionCount > 0
                        ? "Bazi supheli km gecisleri ayiklansa da kalan bloklar gercek tuketim gorunumu olusturuyor."
                        : "kWh/100 km sonucu tutarli km verisiyle dogrulandi."
            )
        }

        if let factoryConsumption = vehicle.factoryConsumptionKWh100km,
           isPlausibleConsumption(factoryConsumption) {
            let hadMeasuredSignal = measuredAverage != nil
            return VehicleEfficiencySummary(
                averageEnergyPer100Km: .estimated(factoryConsumption),
                confidence: makeConfidence(
                    source: .estimated,
                    sampleCount: max(sessions.filter { ($0.energyKWh ?? 0) > 0 }.count, 1),
                    exactSampleCount: 0,
                    estimatedSampleCount: 1,
                    missingSampleCount: max(sessions.count - 1, 0)
                ),
                headline: hadMeasuredSignal
                    ? "Tuketim degeri guvenli banda cekildi"
                    : "Tuketim icin tahmini gorunum kullaniyoruz",
                supportingText: hadMeasuredSignal
                    ? "Km zincirinde supheli veri var. Simdilik fabrikanin tuketim degeriyle guvenli fallback gosteriliyor."
                    : "Daha fazla odometre verisi geldikce gercek tuketim burada netlesecek."
            )
        }

        return nil
    }

    private func buildVehicleEfficiencySummary(
        from snapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot]
    ) -> VehicleEfficiencySummary? {
        guard let snapshot = snapshots[.last365Days] ?? snapshots[.allTime],
              let avgKWh100Km = snapshot.avgKWh100Km,
              isPlausibleConsumption(avgKWh100Km) else {
            return nil
        }

        let measuredValue: MeasuredValue<Double> = snapshot.basisLabel == ConsumptionBlockConfidenceType.real.basisLabel
            ? .exact(avgKWh100Km)
            : .estimated(avgKWh100Km)

        return VehicleEfficiencySummary(
            averageEnergyPer100Km: measuredValue,
            confidence: makeConfidence(
                source: measuredValue.isEstimated ? .mixed : .real,
                sampleCount: 3,
                exactSampleCount: measuredValue.isEstimated ? 0 : 3,
                estimatedSampleCount: measuredValue.isEstimated ? 3 : 0,
                missingSampleCount: 0
            ),
            headline: measuredValue.isEstimated
                ? "Tuketim gorunumu kayitli metriklerden tahmini yuklendi"
                : "Tuketim gorunumun kayitli surus verinle hizali",
            supportingText: measuredValue.isEstimated
                ? "Snapshot verisi onceki surus bloklarindan derlenen tahmini gorunumu kullaniyor; yeni kayitlarla kendini gunceller."
                : "Snapshot verisi dogrulanmis km bloklarina dayaniyor."
        )
    }

    private func bestRangeCandidates(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> [SessionRangeCandidate] {
        let sortedSessions = sessions.sorted { $0.sessionDate < $1.sessionDate }
        var candidates: [SessionRangeCandidate] = []
        var previousOdometerSession: ChargingSession?

        for session in sortedSessions {
            defer {
                if session.odometerKM != nil {
                    previousOdometerSession = session
                }
            }

            guard session.socEnd > session.socStart,
                  let energy = session.energyKWh,
                  energy > 0 else {
                continue
            }

            if let tlPer100Km = sessionTLPer100KmValue(
                session: session,
                previousOdometerSession: previousOdometerSession,
                vehicle: vehicle
            ) {
                candidates.append(
                    SessionRangeCandidate(
                        startSOC: session.socStart,
                        endSOC: session.socEnd,
                        rankingValue: tlPer100Km
                    )
                )
                continue
            }

            if let energyPer100Km = sessionEnergyPer100KmValue(
                session: session,
                previousOdometerSession: previousOdometerSession
            ) {
                candidates.append(
                    SessionRangeCandidate(
                        startSOC: session.socStart,
                        endSOC: session.socEnd,
                        rankingValue: energyPer100Km
                    )
                )
            }
        }

        return candidates
    }

    private func sessionTLPer100KmValue(
        session: ChargingSession,
        previousOdometerSession: ChargingSession?,
        vehicle: Vehicle
    ) -> Double? {
        if let exactConsumption = sessionEnergyPer100KmValue(
            session: session,
            previousOdometerSession: previousOdometerSession
        ),
           let tlPerKWh = session.tlPerKWh {
            return tlPerKWh * exactConsumption
        }

        guard let tlPerKWh = session.tlPerKWh,
              let factoryConsumption = vehicle.factoryConsumptionKWh100km,
              isPlausibleConsumption(factoryConsumption) else {
            return nil
        }
        return tlPerKWh * factoryConsumption
    }

    private func sessionEnergyPer100KmValue(
        session: ChargingSession,
        previousOdometerSession: ChargingSession?
    ) -> Double? {
        guard let previousOdometerSession,
              let currentOdometer = session.odometerKM,
              let previousOdometer = previousOdometerSession.odometerKM,
              let energy = session.energyKWh,
              energy > 0,
              isPlausibleDistance(
                currentOdometer - previousOdometer,
                from: previousOdometerSession.sessionDate,
                to: session.sessionDate
              ) else {
            return nil
        }

        let distance = currentOdometer - previousOdometer
        let value = (energy / distance) * 100
        return isPlausibleConsumption(value) ? value : nil
    }

    private func odometerChainDiagnostics(
        from sessions: [ChargingSession]
    ) -> OdometerChainDiagnostics {
        let ordered = sessions
            .compactMap { session -> (Date, Double)? in
                guard let odometer = session.odometerKM else { return nil }
                return (session.sessionDate, odometer)
            }
            .sorted { $0.0 < $1.0 }

        guard ordered.count >= 2 else {
            return OdometerChainDiagnostics(validTransitionCount: 0, invalidTransitionCount: 0)
        }

        var validTransitionCount = 0
        var invalidTransitionCount = 0

        for index in 1..<ordered.count {
            let previous = ordered[index - 1]
            let next = ordered[index]
            if isPlausibleDistance(next.1 - previous.1, from: previous.0, to: next.0) {
                validTransitionCount += 1
            } else {
                invalidTransitionCount += 1
            }
        }

        return OdometerChainDiagnostics(
            validTransitionCount: validTransitionCount,
            invalidTransitionCount: invalidTransitionCount
        )
    }

    private func isPlausibleDistance(
        _ distance: Double,
        from startDate: Date,
        to endDate: Date
    ) -> Bool {
        guard distance > 0, distance <= EfficiencyLimits.maxDistancePerSessionKM else {
            return false
        }

        let interval = max(endDate.timeIntervalSince(startDate), 3600)
        let intervalDays = interval / 86_400
        let maxPlausibleDistance = max(
            EfficiencyLimits.maxDistancePerDayKM,
            intervalDays * EfficiencyLimits.maxDistancePerDayKM
        )
        return distance <= maxPlausibleDistance
    }

    private func isPlausibleConsumption(_ value: Double) -> Bool {
        value >= EfficiencyLimits.minKWhPer100Km && value <= EfficiencyLimits.maxKWhPer100Km
    }

    private func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middleIndex = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middleIndex - 1] + sorted[middleIndex]) / 2
        }
        return sorted[middleIndex]
    }

    private func makeConfidence(
        source: AnalysisDataSourceKind,
        sampleCount: Int,
        exactSampleCount: Int,
        estimatedSampleCount: Int,
        missingSampleCount: Int
    ) -> DataConfidenceScore {
        let preferredSampleCount = 5.0
        let coverage = min(Double(sampleCount) / preferredSampleCount, 1)
        let baseScore: Double
        switch source {
        case .real:
            baseScore = 92
        case .mixed:
            baseScore = 74
        case .estimated:
            baseScore = 58
        case .unavailable:
            baseScore = 0
        }

        return DataConfidenceScore(
            score: Int((baseScore * coverage).rounded()),
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactSampleCount,
            estimatedSampleCount: estimatedSampleCount,
            missingSampleCount: missingSampleCount
        )
    }

    private func mergeConfidence(_ scores: [DataConfidenceScore]) -> DataConfidenceScore? {
        let validScores = scores.filter { $0.source != .unavailable }
        guard !validScores.isEmpty else { return nil }

        let totalSampleCount = validScores.map(\.sampleCount).max() ?? 0
        let exactSampleCount = validScores.map(\.exactSampleCount).max() ?? 0
        let estimatedSampleCount = validScores.map(\.estimatedSampleCount).max() ?? 0
        let missingSampleCount = validScores.map(\.missingSampleCount).max() ?? 0
        let averageScore = Int(
            (Double(validScores.map(\.score).reduce(0, +)) / Double(validScores.count)).rounded()
        )
        let source: AnalysisDataSourceKind
        let sources = validScores.map(\.source)
        if sources.allSatisfy({ $0 == .real }) {
            source = .real
        } else if sources.allSatisfy({ $0 == .estimated }) {
            source = .estimated
        } else {
            source = .mixed
        }

        return DataConfidenceScore(
            score: averageScore,
            source: source,
            sampleCount: totalSampleCount,
            exactSampleCount: exactSampleCount,
            estimatedSampleCount: estimatedSampleCount,
            missingSampleCount: missingSampleCount
        )
    }

    private struct SessionRangeCandidate {
        let startSOC: Double
        let endSOC: Double
        let rankingValue: Double
    }

    private struct OdometerChainDiagnostics {
        let validTransitionCount: Int
        let invalidTransitionCount: Int
    }

    private func buildDCOperatorAverages(from sessions: [ChargingSession]) -> [OperatorPriceAverage] {
        let validDCSessions = sessions.filter { session in
            session.chargeMethod == .publicDC && (session.energyKWh ?? 0) > 0
        }

        let grouped = Dictionary(grouping: validDCSessions) { session -> String in
            let name = session.stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Bilinmeyen Operatör" : name
        }

        return grouped.compactMap { operatorName, groupedSessions in
            let totalEnergy = groupedSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalCost = groupedSessions.reduce(0) { $0 + $1.priceTotal }
            guard totalEnergy > 0 else { return nil }

            return OperatorPriceAverage(
                operatorName: operatorName,
                averageTLPerKWh: totalCost / totalEnergy,
                sessionCount: groupedSessions.count
            )
        }
        .sorted { $0.averageTLPerKWh < $1.averageTLPerKWh }
    }

    private func buildSmartChargeSuggestion(from sessions: [ChargingSession]) -> SmartChargeSuggestion? {
        let acSessions = sessions.filter { $0.chargeMethod == .publicAC && ($0.energyKWh ?? 0) > 0 }
        let dcSessions = sessions.filter { $0.chargeMethod == .publicDC && ($0.energyKWh ?? 0) > 0 }

        let acEnergy = acSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let acCost = acSessions.reduce(0) { $0 + $1.priceTotal }
        let dcEnergy = dcSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let dcCost = dcSessions.reduce(0) { $0 + $1.priceTotal }
        let currencyCode = sessions.first?.currencyCode ?? AppConstants.defaultCurrencyCode

        guard acEnergy > 0, dcEnergy > 0 else {
            return nil
        }

        let acAverage = acCost / acEnergy
        let dcAverage = dcCost / dcEnergy
        let potentialSavings = max(0, (dcAverage - acAverage) * dcEnergy)

        let message: String
        let title: String
        if potentialSavings > 0 {
            title = "Bu ay için maliyet fırsatı"
            message = "Bu ay DC yerine AC kullansaydın \(NumberFormatting.currency(potentialSavings, code: currencyCode)) daha az ödeyebilirdin."
        } else {
            title = "Bu ay için fiyat dengesi"
            message = "AC ve DC birim maliyetleri bu ay birbirine çok yakın görünüyor."
        }

        return SmartChargeSuggestion(
            title: title,
            message: message,
            potentialSavings: potentialSavings,
            comparedEnergyKWh: dcEnergy,
            acAverageTLPerKWh: acAverage,
            dcAverageTLPerKWh: dcAverage,
            currencyCode: currencyCode
        )
    }

    private func buildExperimentSuggestionReport(
        report: ChargeInsightReport?,
        profile: UserChargingProfileReport?,
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> ExperimentSuggestionReport? {
        guard let report else { return nil }
        return environment.experimentSuggestionService.makeReport(
            report: report,
            profile: profile,
            sessions: sessions,
            referenceDate: referenceDate
        )
    }

    private func resolveTLPerKWhTrendCurrencyCode(from sessions: [ChargingSession]) -> String {
        sessions.first(where: { ($0.energyKWh ?? 0) > 0 })?.currencyCode ?? AppConstants.defaultCurrencyCode
    }

    private func buildTLPerKWhTrend(
        from sessions: [ChargingSession],
        referenceDate: Date
    ) -> [TLPerKWhTrendPoint] {
        let calendar = Calendar.current
        let endDate = referenceDate
        let startDate = calendar.date(
            byAdding: .day,
            value: -(TrendConstants.trailingDays - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)

        let validSessions = sessions.filter { session in
            guard let energy = session.energyKWh, energy > 0 else { return false }
            return session.sessionDate >= startDate && session.sessionDate <= endDate
        }

        let groupedByDay = Dictionary(grouping: validSessions) { session in
            calendar.startOfDay(for: session.sessionDate)
        }

        return groupedByDay.compactMap { day, daySessions in
            let totalEnergy = daySessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let totalCost = daySessions.reduce(0) { $0 + $1.priceTotal }
            guard totalEnergy > 0 else { return nil }

            return TLPerKWhTrendPoint(
                date: day,
                averageTLPerKWh: totalCost / totalEnergy,
                sessionCount: daySessions.count
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func buildMonthlyEVCostTrend(
        from sessions: [ChargingSession],
        referenceDate: Date
    ) -> [MonthlyEVCostPoint] {
        guard !sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let latestMonth = sessions
            .map { calendar.startOfDay(for: $0.sessionDate.startOfMonth) }
            .max() ?? calendar.startOfDay(for: referenceDate.startOfMonth)
        let startMonth = calendar.date(
            byAdding: .month,
            value: -(TrendConstants.trailingMonths - 1),
            to: latestMonth
        ) ?? latestMonth
        let endOfLatestMonth = latestMonth.endOfMonth

        let sessionsInRange = sessions.filter { session in
            session.sessionDate >= startMonth && session.sessionDate <= endOfLatestMonth
        }
        let groupedByMonth = Dictionary(grouping: sessionsInRange) { session in
            calendar.startOfDay(for: session.sessionDate.startOfMonth)
        }

        let monthAxis: [Date] = (0..<TrendConstants.trailingMonths).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: startMonth)
        }

        return monthAxis.map { monthStart in
            let monthSessions = groupedByMonth[monthStart] ?? []
            let totalCost = monthSessions.reduce(0) { $0 + $1.priceTotal }
            let totalEnergy = monthSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
            let averageTLPerKWh = totalEnergy > 0 ? totalCost / totalEnergy : nil

            return MonthlyEVCostPoint(
                date: monthStart,
                totalCost: totalCost,
                totalEnergyKWh: totalEnergy,
                averageTLPerKWh: averageTLPerKWh,
                sessionCount: monthSessions.count
            )
        }
    }
}
