import Foundation

public struct RecommendationInput: Equatable {
    public let usageMode: UsageMode
    public let report: ChargeInsightReport?
    public let savingsSummary: SavingsSummary?
    public let suggestedGoals: SuggestedGoalSet?
    public let activeGoals: [UserGoal]
    public let referenceDate: Date

    public init(
        usageMode: UsageMode,
        report: ChargeInsightReport?,
        savingsSummary: SavingsSummary?,
        suggestedGoals: SuggestedGoalSet?,
        activeGoals: [UserGoal],
        referenceDate: Date = .now
    ) {
        self.usageMode = usageMode
        self.report = report
        self.savingsSummary = savingsSummary
        self.suggestedGoals = suggestedGoals
        self.activeGoals = activeGoals
        self.referenceDate = referenceDate
    }
}

public struct RecommendationEngine {
    private enum Constants {
        static let dcBaseThreshold = 60.0
        static let acTarget = 25.0
        static let maxRecommendations = 3
    }

    private let composer: InsightComposer

    public init(composer: InsightComposer = .init()) {
        self.composer = composer
    }

    public func buildRecommendations(_ input: RecommendationInput) -> [Recommendation] {
        var items: [Recommendation] = []

        let ratios = input.report?.usageRatios
        let dcRatio = ratios?.dcRatio.value ?? 0
        let acRatio = ratios?.acRatio.value ?? 0
        let homeRatio = ratios?.homeRatio.value ?? 0

        let dcThreshold = Constants.dcBaseThreshold * input.usageMode.dcToleranceMultiplier

        if dcRatio >= dcThreshold {
            let suggestedChargeType: ChargeMethod = homeRatio > acRatio ? .home : .publicAC
            let target = max(45, min(dcThreshold, dcRatio - 8))
            items.append(
                Recommendation(
                    id: "rec.reduce_dc",
                    title: "DC oranını düşür",
                    detail: composer.dcReductionMessage(current: dcRatio, target: target),
                    impactText: "Bu ay maliyeti düşürebilir.",
                    confidence: .medium,
                    ctaType: .addCharge,
                    priority: 1,
                    suggestedChargeType: suggestedChargeType
                )
            )
        }

        if acRatio < Constants.acTarget {
            items.append(
                Recommendation(
                    id: "rec.increase_ac",
                    title: "AC ağırlığını artır",
                    detail: composer.acIncreaseMessage(target: Constants.acTarget),
                    impactText: "Daha dengeli maliyet sağlar.",
                    confidence: .medium,
                    ctaType: .addCharge,
                    priority: 2,
                    suggestedChargeType: .publicAC
                )
            )
        }

        if let target = resolvedSpendingTarget(input: input) {
            items.append(
                Recommendation(
                    id: "rec.spending_goal",
                    title: "Harcama hedefini uygula",
                    detail: composer.spendingTargetMessage(
                        amount: target,
                        currencyCode: input.report?.currencyCode ?? AppConstants.defaultCurrencyCode
                    ),
                    impactText: "Aylık bütçeyi korumaya yardımcı olur.",
                    confidence: .medium,
                    ctaType: input.activeGoals.isEmpty ? .acceptGoal : .openGoals,
                    priority: 3,
                    suggestedChargeType: nil
                )
            )
        }

        if input.report == nil && (input.suggestedGoals?.goals.isEmpty ?? true) {
            items.append(
                Recommendation(
                    id: "rec.first_goal",
                    title: "İlk hedef setini oluştur",
                    detail: "Birkaç şarjdan sonra otomatik hedefleri netleştireceğiz.",
                    impactText: nil,
                    confidence: .low,
                    ctaType: .openGoals,
                    priority: 0,
                    suggestedChargeType: nil
                )
            )
        }

        let unique = Dictionary(grouping: items, by: \.id).compactMap { $0.value.first }
        return unique.sorted { $0.priority < $1.priority }.prefix(Constants.maxRecommendations).map { $0 }
    }

    private func resolvedSpendingTarget(input: RecommendationInput) -> Double? {
        input.activeGoals.first(where: { $0.type == .monthlySpending })?.targetValue
            ?? input.suggestedGoals?.goals.first(where: { $0.type == .monthlySpending })?.targetValue
    }
}
