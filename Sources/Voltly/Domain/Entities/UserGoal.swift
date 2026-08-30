import Foundation

public enum GoalType: String, Codable, CaseIterable, Identifiable, Sendable {
    case monthlySpending
    case dcUsageRatio
    case monthlyChargeEntries

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .monthlySpending:
            return "Aylik harcama hedefi"
        case .dcUsageRatio:
            return "DC kullanim orani hedefi"
        case .monthlyChargeEntries:
            return "Aylik kayit duzeni hedefi"
        }
    }

    public var shortTitleTR: String {
        switch self {
        case .monthlySpending:
            return "Harcama"
        case .dcUsageRatio:
            return "DC orani"
        case .monthlyChargeEntries:
            return "Kayit duzeni"
        }
    }

    public var iconName: String {
        switch self {
        case .monthlySpending:
            return "banknote"
        case .dcUsageRatio:
            return "bolt.fill"
        case .monthlyChargeEntries:
            return "checklist"
        }
    }
}

public struct UserGoal: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: GoalType
    public let targetValue: Double
    public let isActive: Bool
    public let createdBy: GoalCreatedBy
    public let sourceReason: String?
    public let isAccepted: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        type: GoalType,
        targetValue: Double,
        isActive: Bool = true,
        createdBy: GoalCreatedBy = .user,
        sourceReason: String? = nil,
        isAccepted: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.targetValue = targetValue
        self.isActive = isActive
        self.createdBy = createdBy
        self.sourceReason = sourceReason
        self.isAccepted = isAccepted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum GoalCreatedBy: String, Codable, Equatable, Sendable {
    case user
    case system
}

public enum GoalProgressTone: String, Equatable, Sendable {
    case success
    case neutral
    case warning
}

public struct GoalProgressItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: GoalType
    public let iconName: String
    public let title: String
    public let headline: String
    public let detail: String
    public let currentValueText: String
    public let targetValueText: String
    public let progressFraction: Double
    public let tone: GoalProgressTone

    public init(
        id: UUID,
        type: GoalType,
        iconName: String,
        title: String,
        headline: String,
        detail: String,
        currentValueText: String,
        targetValueText: String,
        progressFraction: Double,
        tone: GoalProgressTone
    ) {
        self.id = id
        self.type = type
        self.iconName = iconName
        self.title = title
        self.headline = headline
        self.detail = detail
        self.currentValueText = currentValueText
        self.targetValueText = targetValueText
        self.progressFraction = progressFraction
        self.tone = tone
    }
}

public struct GoalProgressSnapshot: Equatable, Sendable {
    public let items: [GoalProgressItem]

    public init(items: [GoalProgressItem]) {
        self.items = items
    }
}
