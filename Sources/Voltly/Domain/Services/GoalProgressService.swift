import Foundation

public struct GoalProgressService {
    public init() {}

    public func makeSnapshot(
        goals: [UserGoal],
        monthlySessions: [ChargingSession],
        currencyCode: String
    ) -> GoalProgressSnapshot {
        let activeGoals = goals
            .filter(\.isActive)
            .sorted { $0.type.rawValue < $1.type.rawValue }

        let items = activeGoals.compactMap { goal in
            makeProgressItem(
                goal: goal,
                monthlySessions: monthlySessions,
                currencyCode: currencyCode
            )
        }

        return GoalProgressSnapshot(items: items)
    }

    private func makeProgressItem(
        goal: UserGoal,
        monthlySessions: [ChargingSession],
        currencyCode: String
    ) -> GoalProgressItem? {
        guard goal.targetValue > 0 else {
            return nil
        }

        switch goal.type {
        case .monthlySpending:
            return makeMonthlySpendingItem(goal: goal, sessions: monthlySessions, currencyCode: currencyCode)
        case .dcUsageRatio:
            return makeDCRatioItem(goal: goal, sessions: monthlySessions)
        case .monthlyChargeEntries:
            return makeEntryCountItem(goal: goal, sessions: monthlySessions)
        }
    }

    private func makeMonthlySpendingItem(
        goal: UserGoal,
        sessions: [ChargingSession],
        currencyCode: String
    ) -> GoalProgressItem {
        let currentValue = sessions.reduce(0) { $0 + $1.priceTotal }
        let ratio = currentValue / goal.targetValue
        let progress = clampedProgress(ratio)
        let headline: String
        let detail: String
        let tone: GoalProgressTone

        if currentValue <= goal.targetValue {
            headline = "Hedefine \(NumberFormatting.percent(progress * 100)) ulastin"
            detail = progress >= 0.85
                ? "Aylik harcama sinirina yaklasiyorsun."
                : "Bu ay harcama hedefin kontrollu gidiyor."
            tone = progress >= 0.85 ? .warning : .success
        } else {
            let overflow = ((currentValue - goal.targetValue) / goal.targetValue) * 100
            headline = "Hedefi \(NumberFormatting.percent(overflow)) astin"
            detail = "Bu ay harcama limitinin uzerindesin."
            tone = .warning
        }

        return GoalProgressItem(
            id: goal.id,
            type: goal.type,
            iconName: goal.type.iconName,
            title: goal.type.titleTR,
            headline: headline,
            detail: detail,
            currentValueText: NumberFormatting.currency(currentValue, code: currencyCode),
            targetValueText: NumberFormatting.currency(goal.targetValue, code: currencyCode),
            progressFraction: progress,
            tone: tone
        )
    }

    private func makeDCRatioItem(
        goal: UserGoal,
        sessions: [ChargingSession]
    ) -> GoalProgressItem {
        let currentValue: Double
        if sessions.isEmpty {
            currentValue = 0
        } else {
            let dcCount = sessions.filter { $0.chargeMethod == .publicDC }.count
            currentValue = (Double(dcCount) / Double(sessions.count)) * 100
        }

        let ratio = currentValue / goal.targetValue
        let progress = clampedProgress(ratio)
        let headline: String
        let detail: String
        let tone: GoalProgressTone

        if currentValue <= goal.targetValue {
            headline = "Bu ay DC oranini dusurmeye yaklastin"
            detail = "DC oranin \(NumberFormatting.percent(currentValue)); hedefin en fazla \(NumberFormatting.percent(goal.targetValue))."
            tone = .success
        } else {
            let overflow = currentValue - goal.targetValue
            headline = "DC hedefin \(NumberFormatting.percent(overflow)) ustunde"
            detail = "Bu ay DC kullanimini biraz daha azaltman gerekiyor."
            tone = .warning
        }

        return GoalProgressItem(
            id: goal.id,
            type: goal.type,
            iconName: goal.type.iconName,
            title: goal.type.titleTR,
            headline: headline,
            detail: detail,
            currentValueText: NumberFormatting.percent(currentValue),
            targetValueText: NumberFormatting.percent(goal.targetValue),
            progressFraction: progress,
            tone: tone
        )
    }

    private func makeEntryCountItem(
        goal: UserGoal,
        sessions: [ChargingSession]
    ) -> GoalProgressItem {
        let currentValue = Double(sessions.count)
        let ratio = currentValue / goal.targetValue
        let progress = clampedProgress(ratio)
        let headline: String
        let detail: String
        let tone: GoalProgressTone

        if currentValue >= goal.targetValue {
            headline = "Aylik kayit hedefini tutturdun"
            detail = "Bu ay duzenli kayit girisi yapiyorsun."
            tone = .success
        } else {
            headline = "Hedefinin \(NumberFormatting.percent(progress * 100)) seviyesindesin"
            detail = "Bu ay \(Int(currentValue.rounded())) / \(Int(goal.targetValue.rounded())) kayit tamamlandi."
            tone = progress >= 0.7 ? .neutral : .warning
        }

        return GoalProgressItem(
            id: goal.id,
            type: goal.type,
            iconName: goal.type.iconName,
            title: goal.type.titleTR,
            headline: headline,
            detail: detail,
            currentValueText: "\(Int(currentValue.rounded())) kayit",
            targetValueText: "\(Int(goal.targetValue.rounded())) kayit",
            progressFraction: progress,
            tone: tone
        )
    }

    private func clampedProgress(_ rawValue: Double) -> Double {
        min(max(rawValue, 0), 1)
    }
}
