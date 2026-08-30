import Foundation

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var snapshot: DashboardSnapshot = DashboardSnapshot(
        tlPer100Km: nil,
        averageEnergyPer100Km: nil,
        currencyCode: AppConstants.defaultCurrencyCode,
        monthlyTotalCost: 0,
        monthlyTotalEnergy: 0,
        monthlySessionCount: 0,
        totalSavingsAmount: nil,
        totalSavingsPercent: nil,
        gasolineSavingsPercent: nil,
        gasolineSavingsAmount: nil,
        calculationExplanation: nil,
        trend: [],
        recentSessions: [],
        breakdown: []
    )
    @Published public private(set) var hasActiveVehicle = false
    @Published public private(set) var activeVehicle: Vehicle?
    @Published public private(set) var totalSessionCount = 0
    @Published public private(set) var dailyInsight: DailyInsightOutput?
    @Published public private(set) var retentionPrompt: InAppReminderMessage?
    @Published public private(set) var homeActionRecommendation: Recommendation?
    @Published public private(set) var activePlan: MonthlyPlan?
    @Published public private(set) var smartRecommendationsEnabled = true
    @Published public private(set) var betaDashboardCardsEnabled = false
    @Published public private(set) var errorMessage: String?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func makeMonthlyEVReportViewModel() -> MonthlyEVReportViewModel {
        MonthlyEVReportViewModel(environment: environment)
    }

    public func makeSuggestedChargeViewModel() -> AddChargeViewModel? {
        guard let suggestedChargeType = homeActionRecommendation?.suggestedChargeType else {
            return nil
        }
        let viewModel = AddChargeViewModel(environment: environment)
        switch suggestedChargeType {
        case .home:
            viewModel.applySuggestedDefaultChargeType(.home)
        case .publicAC:
            viewModel.applySuggestedDefaultChargeType(.ac)
        case .publicDC:
            viewModel.applySuggestedDefaultChargeType(.dc)
        }
        return viewModel
    }

    public func load(referenceDate: Date = .now) {
        do {
            refreshFeatureFlags()
            activeVehicle = try environment.vehicleRepository.fetchActiveVehicle()
            hasActiveVehicle = activeVehicle != nil
            let sessions: [ChargingSession]
            if let activeVehicle {
                sessions = try environment.listChargingSessionsUseCase.execute(vehicleID: activeVehicle.id)
                totalSessionCount = sessions.count
            } else {
                sessions = []
                totalSessionCount = 0
            }
            snapshot = try environment.getDashboardSnapshotUseCase.execute(referenceDate: referenceDate)
            refreshBehaviorState(
                sessions: sessions,
                referenceDate: referenceDate
            )
            refreshDailyInsight(referenceDate: referenceDate)
            refreshRetentionPrompt(sessions: sessions, referenceDate: referenceDate)
            WidgetSharedStore.save(snapshot: snapshot)
            environment.analytics.track(.dashboardViewed)
            if snapshot.gasolineSavingsPercent != nil {
                environment.analytics.track(.savingsBadgeViewed)
            }
        } catch {
            errorMessage = error.localizedDescription
            retentionPrompt = nil
            homeActionRecommendation = nil
            activePlan = nil
        }
    }

    public func trackChartInteraction() {
        environment.analytics.track(.dashboardChartInteracted)
    }

    private func refreshDailyInsight(referenceDate: Date) {
        guard smartRecommendationsEnabled else {
            dailyInsight = nil
            return
        }

        guard hasActiveVehicle, totalSessionCount > 0 else {
            dailyInsight = nil
            return
        }

        environment.dailyInsightCoordinator.refreshCandidate(referenceDate: referenceDate)
        dailyInsight = environment.dailyInsightCoordinator.consumeDisplayableInsight(
            referenceDate: referenceDate
        )
    }

    private func refreshRetentionPrompt(
        sessions: [ChargingSession],
        referenceDate: Date
    ) {
        guard smartRecommendationsEnabled else {
            retentionPrompt = nil
            return
        }

        guard hasActiveVehicle else {
            retentionPrompt = nil
            return
        }

        do {
            let goals = try environment.goalRepository.fetchGoals()
            retentionPrompt = environment.retentionPromptService.generatePrompt(
                sessions: sessions,
                goals: goals,
                referenceDate: referenceDate
            )
        } catch {
            retentionPrompt = nil
        }
    }

    private func refreshFeatureFlags() {
        smartRecommendationsEnabled = environment.featureAccessChecker.isEnabled(.smartRecommendations)
        betaDashboardCardsEnabled = environment.featureAccessChecker.isEnabled(.betaDashboardCards)
    }

    private func refreshBehaviorState(
        sessions: [ChargingSession],
        referenceDate: Date
    ) {
        guard hasActiveVehicle,
              let vehicle = activeVehicle else {
            homeActionRecommendation = nil
            activePlan = nil
            return
        }

        do {
            let usageMode = environment.usageModeStore.loadUsageMode()
            let goals = try environment.goalRepository.fetchGoals()
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let report = sessions.isEmpty
                ? nil
                : environment.chargeInsightService.analyze(
                    vehicle: vehicle,
                    sessions: sessions,
                    referenceDate: referenceDate
                )
            let savingsReport = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: sessions,
                preferences: baseline,
                referenceDate: referenceDate
            )
            let suggestedGoals = environment.goalSuggestionEngine.suggest(
                input: GoalSuggestionInput(
                    usageMode: usageMode,
                    report: report,
                    savingsReport: savingsReport,
                    sessions: sessions,
                    referenceDate: referenceDate
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
            let builtPlan = environment.monthlyPlanEngine.buildPlan(
                MonthlyPlanInput(
                    usageMode: usageMode,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    sessions: sessions,
                    referenceDate: referenceDate
                ),
                confidence: confidence
            )
            activePlan = environment.habitProgressEngine.evaluate(
                PlanProgressInput(
                    plan: builtPlan,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    sessions: sessions,
                    referenceDate: referenceDate
                )
            )
            let recommendations = environment.recommendationEngine.buildRecommendations(
                RecommendationInput(
                    usageMode: usageMode,
                    report: report,
                    savingsSummary: savingsReport.thisMonth ?? savingsReport.last30Days,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    referenceDate: referenceDate
                )
            )
            homeActionRecommendation = environment.homeActionCardProvider.makeActionCard(from: recommendations)
        } catch {
            homeActionRecommendation = nil
            activePlan = nil
        }
    }
}
