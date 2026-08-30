import Foundation

public struct MonthlyPlanInput: Equatable {
    public let usageMode: UsageMode
    public let suggestedGoals: SuggestedGoalSet?
    public let activeGoals: [UserGoal]
    public let report: ChargeInsightReport?
    public let savingsSummary: SavingsSummary?
    public let sessions: [ChargingSession]
    public let referenceDate: Date

    public init(
        usageMode: UsageMode,
        suggestedGoals: SuggestedGoalSet?,
        activeGoals: [UserGoal],
        report: ChargeInsightReport?,
        savingsSummary: SavingsSummary?,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) {
        self.usageMode = usageMode
        self.suggestedGoals = suggestedGoals
        self.activeGoals = activeGoals
        self.report = report
        self.savingsSummary = savingsSummary
        self.sessions = sessions
        self.referenceDate = referenceDate
    }
}

public struct MonthlyPlanEngine {
    private enum Constants {
        static let acTarget = 25.0
        static let homeTarget = 15.0
    }

    public init() {}

    public func buildPlan(_ input: MonthlyPlanInput, confidence: RecommendationConfidence) -> MonthlyPlan {
        let monthKey = DateFormatter.monthKey.string(from: input.referenceDate)
        let ratios = input.report?.usageRatios
        let currentDCRatio = ratios?.dcRatio.value ?? 0
        let currentACRatio = ratios?.acRatio.value ?? 0
        let currentHomeRatio = ratios?.homeRatio.value ?? 0

        let goalsByType = Dictionary(uniqueKeysWithValues: input.activeGoals.map { ($0.type, $0) })
        let suggestedByType = Dictionary(uniqueKeysWithValues: input.suggestedGoals?.goals.map { ($0.type, $0) } ?? [])

        var actions: [PlanAction] = []

        if let target = resolvedTargetValue(
            for: .dcUsageRatio,
            goalsByType: goalsByType,
            suggestedByType: suggestedByType
        ) {
            let title = "DC oranını düşür"
            let detail = "DC oranını %\(Int(currentDCRatio.rounded())) → %\(Int(target.rounded())) hedefle."
            actions.append(
                PlanAction(
                    type: .reduceDC,
                    title: title,
                    detail: detail,
                    targetValue: target,
                    currentValue: currentDCRatio,
                    unit: "%",
                    isCompleted: currentDCRatio <= target
                )
            )
        }

        if currentACRatio < Constants.acTarget {
            actions.append(
                PlanAction(
                    type: .increaseAC,
                    title: "AC ağırlığını artır",
                    detail: "AC payını en az %\(Int(Constants.acTarget)) seviyesine yaklaştır.",
                    targetValue: Constants.acTarget,
                    currentValue: currentACRatio,
                    unit: "%",
                    isCompleted: currentACRatio >= Constants.acTarget
                )
            )
        }

        if currentHomeRatio < Constants.homeTarget {
            actions.append(
                PlanAction(
                    type: .increaseHome,
                    title: "Ev şarjını artır",
                    detail: "Ev şarjı payını %\(Int(Constants.homeTarget)) üzerine çıkarmayı dene.",
                    targetValue: Constants.homeTarget,
                    currentValue: currentHomeRatio,
                    unit: "%",
                    isCompleted: currentHomeRatio >= Constants.homeTarget
                )
            )
        }

        if let target = resolvedTargetValue(
            for: .monthlySpending,
            goalsByType: goalsByType,
            suggestedByType: suggestedByType
        ) {
            let currentSpend = input.savingsSummary?.totalEvCost ?? 0
            let detail = "Bu ay toplam harcamayı \(NumberFormatting.currency(target, code: input.report?.currencyCode ?? AppConstants.defaultCurrencyCode)) altında tut."
            actions.append(
                PlanAction(
                    type: .reduceCost,
                    title: "Harcama hedefi",
                    detail: detail,
                    targetValue: target,
                    currentValue: currentSpend,
                    unit: "TL",
                    isCompleted: currentSpend <= target
                )
            )
        }

        if let target = resolvedTargetValue(
            for: .monthlyChargeEntries,
            goalsByType: goalsByType,
            suggestedByType: suggestedByType
        ) {
            let count = sessionsThisMonth(input.sessions, referenceDate: input.referenceDate).count
            let detail = "Bu ay en az \(Int(target.rounded())) kayıt hedefle."
            actions.append(
                PlanAction(
                    type: .maintainEntryConsistency,
                    title: "Kayıt düzeni",
                    detail: detail,
                    targetValue: target,
                    currentValue: Double(count),
                    unit: "seans",
                    isCompleted: Double(count) >= target
                )
            )
        }

        let progress = PlanProgress(
            completedCount: actions.filter(\.isCompleted).count,
            totalCount: actions.count
        )

        let title = "Bu ay planın"
        let summary = makeSummary(
            usageMode: input.usageMode,
            actions: actions
        )
        let expectedSavings = estimateExpectedSavings(
            savingsSummary: input.savingsSummary,
            targetValue: resolvedTargetValue(
                for: .monthlySpending,
                goalsByType: goalsByType,
                suggestedByType: suggestedByType
            )
        )

        return MonthlyPlan(
            monthKey: monthKey,
            title: title,
            summary: summary,
            expectedSavings: expectedSavings,
            confidence: confidence,
            actions: actions,
            progress: progress,
            status: .active
        )
    }

    private func makeSummary(
        usageMode: UsageMode,
        actions: [PlanAction]
    ) -> String {
        if actions.isEmpty {
            return "Bu ay davranışın dengeli görünüyor."
        }
        switch usageMode {
        case .savingsFocused:
            return "Bu ay tasarrufa odaklı bir plan hazır."
        case .balanced:
            return "Maliyet ve pratikliği dengede tutan bir plan."
        case .speedFocused:
            return "Hızlı şarjı korurken maliyeti dengeleyen bir plan."
        }
    }

    private func estimateExpectedSavings(
        savingsSummary: SavingsSummary?,
        targetValue: Double?
    ) -> Double? {
        guard let targetValue else { return nil }
        let current = savingsSummary?.totalEvCost ?? 0
        if current <= 0 { return nil }
        return max(0, current - targetValue)
    }

    private func resolvedTargetValue(
        for type: GoalType,
        goalsByType: [GoalType: UserGoal],
        suggestedByType: [GoalType: SuggestedGoal]
    ) -> Double? {
        goalsByType[type]?.targetValue ?? suggestedByType[type]?.targetValue
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
