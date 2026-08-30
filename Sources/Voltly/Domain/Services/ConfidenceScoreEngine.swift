import Foundation

public struct ConfidenceScoreInput: Equatable, Sendable {
    public let sampleCount: Int
    public let dataConfidence: DataConfidenceScore?
    public let hasCostData: Bool
    public let hasDistanceData: Bool

    public init(
        sampleCount: Int,
        dataConfidence: DataConfidenceScore?,
        hasCostData: Bool,
        hasDistanceData: Bool
    ) {
        self.sampleCount = sampleCount
        self.dataConfidence = dataConfidence
        self.hasCostData = hasCostData
        self.hasDistanceData = hasDistanceData
    }
}

public struct ConfidenceScoreEngine {
    public init() {}

    public func evaluate(_ input: ConfidenceScoreInput) -> RecommendationConfidence {
        var score = 0
        if input.sampleCount >= 10 { score += 2 }
        else if input.sampleCount >= 5 { score += 1 }

        if let confidence = input.dataConfidence {
            if confidence.score >= 75 { score += 2 }
            else if confidence.score >= 50 { score += 1 }
        }

        if input.hasCostData { score += 1 }
        if input.hasDistanceData { score += 1 }

        switch score {
        case 5...6:
            return .high
        case 3...4:
            return .medium
        default:
            return .low
        }
    }
}
