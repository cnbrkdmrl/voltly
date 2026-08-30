import Foundation

public struct GoalSuggestionInput: Equatable {
    public let usageMode: UsageMode
    public let report: ChargeInsightReport?
    public let savingsReport: SavingsCalculationReport?
    public let sessions: [ChargingSession]
    public let referenceDate: Date

    public init(
        usageMode: UsageMode,
        report: ChargeInsightReport?,
        savingsReport: SavingsCalculationReport?,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) {
        self.usageMode = usageMode
        self.report = report
        self.savingsReport = savingsReport
        self.sessions = sessions
        self.referenceDate = referenceDate
    }
}

public struct GoalSuggestionEngine {
    private enum Constants {
        static let minimumDataSessions = 3
        static let baseDCThreshold = 60.0
        static let baseSavingsImprovement: Double = 0.08
        static let minMonthlySpend: Double = 300
        static let minMonthlyEntries: Int = 4
        static let lowDataMonthlyEntries: Int = 3
        static let maxSuggestedEntries: Int = 16
    }

    public init() {}

    public func suggest(input: GoalSuggestionInput) -> SuggestedGoalSet {
        let recentSessions = sessionsInPastDays(input.sessions, days: 30, endingAt: input.referenceDate)
        let midSessions = sessionsInPastDays(input.sessions, days: 60, endingAt: input.referenceDate)
        let longSessions = sessionsInPastDays(input.sessions, days: 90, endingAt: input.referenceDate)

        let activeSessions: [ChargingSession]
        if recentSessions.count >= Constants.minimumDataSessions {
            activeSessions = recentSessions
        } else if midSessions.count >= Constants.minimumDataSessions {
            activeSessions = midSessions
        } else if longSessions.count >= Constants.minimumDataSessions {
            activeSessions = longSessions
        } else {
            activeSessions = input.sessions
        }

        let usageRatios = input.report?.usageRatios
        let dcRatio = usageRatios?.dcRatio.value ?? 0
        let monthlyCost = input.savingsReport?.last30Days?.totalEvCost
            ?? input.savingsReport?.thisMonth?.totalEvCost
            ?? activeSessions.reduce(0) { $0 + $1.priceTotal }

        let improvementRate = resolveSavingsImprovementRate(
            usageMode: input.usageMode,
            sampleCount: activeSessions.count
        )

        let spendingTarget = max(Constants.minMonthlySpend, monthlyCost * (1 - improvementRate))
        let dcTarget = suggestedDCTarget(currentRatio: dcRatio, usageMode: input.usageMode)
        let entryTarget = suggestedEntryTarget(from: activeSessions)

        var suggestions: [SuggestedGoal] = []

        suggestions.append(
            SuggestedGoal(
                type: .monthlySpending,
                targetValue: spendingTarget,
                reason: activeSessions.isEmpty
                    ? "İlk hedef seti için konservatif aylık limit."
                    : "Son dönem harcama trendine göre dengeli bir limit.",
                confidence: confidence(for: activeSessions.count)
            )
        )

        if dcRatio > 0 {
            suggestions.append(
                SuggestedGoal(
                    type: .dcUsageRatio,
                    targetValue: dcTarget,
                    reason: "DC oranını daha kontrollü tutmak maliyeti dengeler.",
                    confidence: confidence(for: activeSessions.count)
                )
            )
        } else {
            suggestions.append(
                SuggestedGoal(
                    type: .dcUsageRatio,
                    targetValue: dcTarget,
                    reason: "Daha dengeli bir yöntem dağılımı için.",
                    confidence: .low
                )
            )
        }

        suggestions.append(
            SuggestedGoal(
                type: .monthlyChargeEntries,
                targetValue: Double(entryTarget),
                reason: "Kayıt düzenini korumak analiz doğruluğunu artırır.",
                confidence: confidence(for: activeSessions.count)
            )
        )

        return SuggestedGoalSet(
            goals: suggestions,
            title: "Voltly senin için hedef önerdi",
            subtitle: "Son verilerine göre otomatik bir hedef seti oluşturuldu."
        )
    }

    private func resolveSavingsImprovementRate(
        usageMode: UsageMode,
        sampleCount: Int
    ) -> Double {
        let base = Constants.baseSavingsImprovement * usageMode.savingsAggressionMultiplier
        if sampleCount < Constants.minimumDataSessions {
            return min(base, 0.05)
        }
        return min(max(base, 0.05), 0.12)
    }

    private func suggestedDCTarget(
        currentRatio: Double,
        usageMode: UsageMode
    ) -> Double {
        let baseTarget: Double
        switch usageMode {
        case .savingsFocused:
            baseTarget = Constants.baseDCThreshold - 5
        case .balanced:
            baseTarget = Constants.baseDCThreshold
        case .speedFocused:
            baseTarget = Constants.baseDCThreshold + 5
        }

        if currentRatio <= 0 {
            return baseTarget
        }

        if currentRatio > baseTarget {
            return max(baseTarget, currentRatio - 8)
        }
        return max(currentRatio, baseTarget - 8)
    }

    private func suggestedEntryTarget(from sessions: [ChargingSession]) -> Int {
        let count = sessions.count
        if count == 0 {
            return Constants.lowDataMonthlyEntries
        }
        let target = max(Constants.minMonthlyEntries, Int(round(Double(count))))
        return min(target + 1, Constants.maxSuggestedEntries)
    }

    private func confidence(for sampleCount: Int) -> RecommendationConfidence {
        if sampleCount >= 8 {
            return .high
        }
        if sampleCount >= 4 {
            return .medium
        }
        return .low
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
}
