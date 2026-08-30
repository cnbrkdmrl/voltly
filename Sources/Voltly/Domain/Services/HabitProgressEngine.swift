import Foundation

public struct PlanProgressInput: Equatable {
    public let plan: MonthlyPlan
    public let report: ChargeInsightReport?
    public let savingsSummary: SavingsSummary?
    public let sessions: [ChargingSession]
    public let referenceDate: Date

    public init(
        plan: MonthlyPlan,
        report: ChargeInsightReport?,
        savingsSummary: SavingsSummary?,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) {
        self.plan = plan
        self.report = report
        self.savingsSummary = savingsSummary
        self.sessions = sessions
        self.referenceDate = referenceDate
    }
}

public struct HabitProgressEngine {
    public init() {}

    public func evaluate(_ input: PlanProgressInput) -> MonthlyPlan {
        let evaluatedActions = input.plan.actions.map { action in
            evaluate(action: action, input: input)
        }
        let completed = evaluatedActions.filter(\.isCompleted).count
        let progress = PlanProgress(completedCount: completed, totalCount: evaluatedActions.count)

        return MonthlyPlan(
            id: input.plan.id,
            monthKey: input.plan.monthKey,
            title: input.plan.title,
            summary: input.plan.summary,
            expectedSavings: input.plan.expectedSavings,
            confidence: input.plan.confidence,
            actions: evaluatedActions,
            progress: progress,
            status: progress.fraction >= 0.99 ? .completed : input.plan.status,
            createdAt: input.plan.createdAt,
            updatedAt: .now
        )
    }

    private func evaluate(action: PlanAction, input: PlanProgressInput) -> PlanAction {
        let report = input.report
        let ratios = report?.usageRatios

        switch action.type {
        case .reduceDC:
            let current = ratios?.dcRatio.value ?? 0
            let target = action.targetValue ?? 0
            let completed = target > 0 ? current <= target : false
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: target,
                currentValue: current,
                unit: "%",
                isCompleted: completed
            )
        case .increaseAC:
            let current = ratios?.acRatio.value ?? 0
            let target = action.targetValue ?? 0
            let completed = target > 0 ? current >= target : false
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: target,
                currentValue: current,
                unit: "%",
                isCompleted: completed
            )
        case .increaseHome:
            let current = ratios?.homeRatio.value ?? 0
            let target = action.targetValue ?? 0
            let completed = target > 0 ? current >= target : false
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: target,
                currentValue: current,
                unit: "%",
                isCompleted: completed
            )
        case .maintainEntryConsistency:
            let count = sessionsThisMonth(input.sessions, referenceDate: input.referenceDate).count
            let target = action.targetValue ?? 0
            let completed = target > 0 ? Double(count) >= target : false
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: target,
                currentValue: Double(count),
                unit: "seans",
                isCompleted: completed
            )
        case .reduceCost:
            let current = input.savingsSummary?.totalEvCost ?? 0
            let target = action.targetValue ?? 0
            let completed = target > 0 ? current <= target : false
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: target,
                currentValue: current,
                unit: "TL",
                isCompleted: completed
            )
        case .avoidExpensiveOperator:
            return PlanAction(
                id: action.id,
                type: action.type,
                title: action.title,
                detail: action.detail,
                targetValue: action.targetValue,
                currentValue: action.currentValue,
                unit: action.unit,
                isCompleted: action.isCompleted
            )
        }
    }

    private func sessionsThisMonth(
        _ sessions: [ChargingSession],
        referenceDate: Date
    ) -> [ChargingSession] {
        let start = referenceDate.startOfMonth
        let end = referenceDate.endOfMonth
        return sessions.filter { $0.sessionDate >= start && $0.sessionDate <= end }
    }
}
