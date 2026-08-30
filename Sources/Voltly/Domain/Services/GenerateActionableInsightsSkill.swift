import Foundation

public enum ActionableInsightRecommendationType: String, Equatable, Sendable {
    case reduceDC = "reduce_dc"
    case increaseAC = "increase_ac"
    case optimizeRange = "optimize_range"
}

public enum SuggestedChargeDefaultType: String, Equatable, Sendable {
    case ac = "AC"
    case dc = "DC"
    case home = "HOME"

    public var chargeMethod: ChargeMethod {
        switch self {
        case .ac:
            return .publicAC
        case .dc:
            return .publicDC
        case .home:
            return .home
        }
    }
}

public struct ActionableInsightSuggestedAction: Equatable, Sendable {
    public let defaultChargeType: SuggestedChargeDefaultType

    public init(defaultChargeType: SuggestedChargeDefaultType) {
        self.defaultChargeType = defaultChargeType
    }
}

public struct GenerateActionableInsightsInput: Equatable, Sendable {
    public let dcUsageRatio: Double?
    public let acUsageRatio: Double?
    public let homeUsageRatio: Double?
    public let averageChargeRange: Double?

    public init(
        dcUsageRatio: Double?,
        acUsageRatio: Double?,
        homeUsageRatio: Double?,
        averageChargeRange: Double?
    ) {
        self.dcUsageRatio = dcUsageRatio
        self.acUsageRatio = acUsageRatio
        self.homeUsageRatio = homeUsageRatio
        self.averageChargeRange = averageChargeRange
    }
}

public struct ActionableAnalysisInsight: Identifiable, Equatable, Sendable {
    public let recommendationType: ActionableInsightRecommendationType
    public let message: String
    public let suggestedAction: ActionableInsightSuggestedAction

    public init(
        recommendationType: ActionableInsightRecommendationType,
        message: String,
        suggestedAction: ActionableInsightSuggestedAction
    ) {
        self.recommendationType = recommendationType
        self.message = message
        self.suggestedAction = suggestedAction
    }

    public var id: String {
        recommendationType.rawValue
    }
}

public struct GenerateActionableInsightsSkill {
    private enum Rules {
        static let reduceDCRatioThreshold = 65.0
        static let increaseACRatioThreshold = 25.0
        static let optimizeRangeThreshold = 80.0
    }

    private enum Priority: Int {
        case optimizeRange = 100
        case increaseAC = 200
        case reduceDC = 300
    }

    public init() {}

    public func generateInsight(
        input: GenerateActionableInsightsInput
    ) -> ActionableAnalysisInsight? {
        let matches = matchedRules(for: input)
        guard let highest = matches.max(by: { $0.priority.rawValue < $1.priority.rawValue }) else {
            return nil
        }
        return highest.insight
    }

    private func matchedRules(
        for input: GenerateActionableInsightsInput
    ) -> [(priority: Priority, insight: ActionableAnalysisInsight)] {
        var items: [(Priority, ActionableAnalysisInsight)] = []

        if let dcUsageRatio = input.dcUsageRatio,
           dcUsageRatio > Rules.reduceDCRatioThreshold {
            items.append((
                .reduceDC,
                ActionableAnalysisInsight(
                    recommendationType: .reduceDC,
                    message: "DC kullanımın %\(Int(dcUsageRatio.rounded())) seviyesinde. Maliyeti dengelemek için sıradaki planı AC ağırlıklı kur.",
                    suggestedAction: ActionableInsightSuggestedAction(defaultChargeType: suggestedDefaultTypeForReducedDC(input: input))
                )
            ))
        }

        if let acUsageRatio = input.acUsageRatio,
           acUsageRatio < Rules.increaseACRatioThreshold {
            items.append((
                .increaseAC,
                ActionableAnalysisInsight(
                    recommendationType: .increaseAC,
                    message: "AC kullanımın %\(Int(acUsageRatio.rounded())) seviyesinde kaldı. Düzenli AC kullanımı birim maliyeti aşağı çekebilir.",
                    suggestedAction: ActionableInsightSuggestedAction(defaultChargeType: .ac)
                )
            ))
        }

        if let averageChargeRange = input.averageChargeRange,
           averageChargeRange > Rules.optimizeRangeThreshold {
            items.append((
                .optimizeRange,
                ActionableAnalysisInsight(
                    recommendationType: .optimizeRange,
                    message: "Ortalama şarj aralığın %\(Int(averageChargeRange.rounded())) görünüyor. Daha dar aralıkla planlamak süreyi ve maliyeti optimize edebilir.",
                    suggestedAction: ActionableInsightSuggestedAction(defaultChargeType: suggestedDefaultTypeForRangeOptimization(input: input))
                )
            ))
        }

        return items
    }

    private func suggestedDefaultTypeForReducedDC(
        input: GenerateActionableInsightsInput
    ) -> SuggestedChargeDefaultType {
        let homeRatio = input.homeUsageRatio ?? 0
        let acRatio = input.acUsageRatio ?? 0
        return homeRatio >= acRatio && homeRatio > 0 ? .home : .ac
    }

    private func suggestedDefaultTypeForRangeOptimization(
        input: GenerateActionableInsightsInput
    ) -> SuggestedChargeDefaultType {
        let homeRatio = input.homeUsageRatio ?? 0
        return homeRatio > 0 ? .home : .ac
    }
}
