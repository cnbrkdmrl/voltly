import Foundation

public enum RecommendationConfidence: String, Equatable, Sendable {
    case low
    case medium
    case high

    public var titleTR: String {
        switch self {
        case .low:
            return "Düşük güven"
        case .medium:
            return "Orta güven"
        case .high:
            return "Yüksek güven"
        }
    }
}

public enum RecommendationCTAType: String, Equatable, Sendable {
    case addCharge
    case acceptGoal
    case openGoals
    case openDetails
}

public struct Recommendation: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let impactText: String?
    public let confidence: RecommendationConfidence
    public let ctaType: RecommendationCTAType
    public let priority: Int
    public let suggestedChargeType: ChargeMethod?

    public init(
        id: String,
        title: String,
        detail: String,
        impactText: String? = nil,
        confidence: RecommendationConfidence,
        ctaType: RecommendationCTAType,
        priority: Int,
        suggestedChargeType: ChargeMethod? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.impactText = impactText
        self.confidence = confidence
        self.ctaType = ctaType
        self.priority = priority
        self.suggestedChargeType = suggestedChargeType
    }
}

public enum SuggestedGoalSource: String, Equatable, Sendable {
    case system
    case user
}

public struct SuggestedGoal: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: GoalType
    public let targetValue: Double
    public let reason: String
    public let confidence: RecommendationConfidence
    public let source: SuggestedGoalSource

    public init(
        id: UUID = UUID(),
        type: GoalType,
        targetValue: Double,
        reason: String,
        confidence: RecommendationConfidence,
        source: SuggestedGoalSource = .system
    ) {
        self.id = id
        self.type = type
        self.targetValue = targetValue
        self.reason = reason
        self.confidence = confidence
        self.source = source
    }
}

public struct SuggestedGoalSet: Equatable, Sendable {
    public let goals: [SuggestedGoal]
    public let title: String
    public let subtitle: String

    public init(goals: [SuggestedGoal], title: String, subtitle: String) {
        self.goals = goals
        self.title = title
        self.subtitle = subtitle
    }
}

public enum PlanStatus: String, Equatable, Sendable {
    case active
    case completed
    case paused
}

public enum PlanActionType: String, Equatable, Sendable {
    case reduceDC
    case increaseAC
    case increaseHome
    case maintainEntryConsistency
    case reduceCost
    case avoidExpensiveOperator
}

public struct PlanAction: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: PlanActionType
    public let title: String
    public let detail: String
    public let targetValue: Double?
    public let currentValue: Double?
    public let unit: String
    public let isCompleted: Bool

    public init(
        id: UUID = UUID(),
        type: PlanActionType,
        title: String,
        detail: String,
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        unit: String,
        isCompleted: Bool
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.isCompleted = isCompleted
    }
}

public struct PlanProgress: Equatable, Sendable {
    public let completedCount: Int
    public let totalCount: Int
    public let fraction: Double

    public init(completedCount: Int, totalCount: Int) {
        self.completedCount = completedCount
        self.totalCount = totalCount
        if totalCount > 0 {
            self.fraction = min(max(Double(completedCount) / Double(totalCount), 0), 1)
        } else {
            self.fraction = 0
        }
    }
}

public struct MonthlyPlan: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let monthKey: String
    public let title: String
    public let summary: String
    public let expectedSavings: Double?
    public let confidence: RecommendationConfidence
    public let actions: [PlanAction]
    public let progress: PlanProgress
    public let status: PlanStatus
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        monthKey: String,
        title: String,
        summary: String,
        expectedSavings: Double?,
        confidence: RecommendationConfidence,
        actions: [PlanAction],
        progress: PlanProgress,
        status: PlanStatus,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.monthKey = monthKey
        self.title = title
        self.summary = summary
        self.expectedSavings = expectedSavings
        self.confidence = confidence
        self.actions = actions
        self.progress = progress
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
