import Foundation

public enum DailyInsightKind: String, Equatable, Sendable {
    case risingCosts
    case dcIncrease
    case savingsDrop
    case savingsIncrease
    case expensivePrimaryStation
    case chargeRangeChanged
}

public struct DailyInsightOutput: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: DailyInsightKind
    public let text: String
    public let priority: Int

    public init(
        id: String,
        kind: DailyInsightKind,
        text: String,
        priority: Int
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.priority = priority
    }
}

public struct DailyInsightTrendData: Equatable, Sendable {
    public let savingsDelta: Double?
    public let averageChargeRangeDelta: Double?

    public init(
        savingsDelta: Double?,
        averageChargeRangeDelta: Double? = nil
    ) {
        self.savingsDelta = savingsDelta
        self.averageChargeRangeDelta = averageChargeRangeDelta
    }
}

public struct DailyInsightUsageStats: Equatable, Sendable {
    public let currentWeekDCRatio: Double?
    public let previousWeekDCRatio: Double?

    public init(
        currentWeekDCRatio: Double?,
        previousWeekDCRatio: Double?
    ) {
        self.currentWeekDCRatio = currentWeekDCRatio
        self.previousWeekDCRatio = previousWeekDCRatio
    }
}

public struct DailyInsightStationStats: Equatable, Sendable {
    public let stationName: String
    public let averageTLPerKWh: Double
    public let overallAverageTLPerKWh: Double
    public let sessionCount: Int

    public init(
        stationName: String,
        averageTLPerKWh: Double,
        overallAverageTLPerKWh: Double,
        sessionCount: Int
    ) {
        self.stationName = stationName
        self.averageTLPerKWh = averageTLPerKWh
        self.overallAverageTLPerKWh = overallAverageTLPerKWh
        self.sessionCount = sessionCount
    }
}

public struct DailyInsightInput: Equatable {
    public let lastSessions: [ChargingSession]
    public let trendData: DailyInsightTrendData
    public let usageStats: DailyInsightUsageStats
    public let stationStats: DailyInsightStationStats?

    public init(
        lastSessions: [ChargingSession],
        trendData: DailyInsightTrendData,
        usageStats: DailyInsightUsageStats,
        stationStats: DailyInsightStationStats? = nil
    ) {
        self.lastSessions = lastSessions
        self.trendData = trendData
        self.usageStats = usageStats
        self.stationStats = stationStats
    }
}

public typealias GenerateDailyInsightInput = DailyInsightInput
public typealias GenerateDailyInsightTrendData = DailyInsightTrendData
public typealias GenerateDailyInsightUsageStats = DailyInsightUsageStats

public struct DailyInsightService {
    private enum Constants {
        static let risingCostsPriority = 320
        static let expensiveStationPriority = 280
        static let savingsDropPriority = 250
        static let dcIncreasePriority = 220
        static let chargeRangeChangedPriority = 180
        static let savingsIncreasePriority = 140

        static let minimumRecentSessions = 3
        static let risingCostMinimumTotalDelta = 0.6
        static let dcIncreaseThreshold = 15.0
        static let savingsChangeThreshold = 50.0
        static let chargeRangeChangeThreshold = 12.0
        static let stationPremiumRatioThreshold = 0.12
        static let minimumPrimaryStationSessions = 3
    }

    public init() {}

    public func generate(input: DailyInsightInput) -> DailyInsightOutput? {
        let insights = [
            risingCostsInsight(from: input.lastSessions),
            expensivePrimaryStationInsight(from: input.stationStats),
            savingsTrendInsight(from: input.trendData),
            dcUsageInsight(from: input.usageStats),
            chargeRangeInsight(from: input.trendData)
        ].compactMap { $0 }

        return insights.max { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id > rhs.id
            }
            return lhs.priority < rhs.priority
        }
    }

    private func risingCostsInsight(from sessions: [ChargingSession]) -> DailyInsightOutput? {
        let recentValues = sessions
            .sorted { $0.sessionDate > $1.sessionDate }
            .compactMap(\.tlPerKWh)
            .prefix(Constants.minimumRecentSessions)

        let values = Array(recentValues)
        guard values.count == Constants.minimumRecentSessions else { return nil }
        guard values[0] > values[1], values[1] > values[2] else { return nil }
        guard (values[0] - values[2]) >= Constants.risingCostMinimumTotalDelta else { return nil }

        return DailyInsightOutput(
            id: "rising-costs",
            kind: .risingCosts,
            text: "Son 3 şarjın kademeli olarak pahalanıyor.",
            priority: Constants.risingCostsPriority
        )
    }

    private func dcUsageInsight(from usageStats: DailyInsightUsageStats) -> DailyInsightOutput? {
        guard let current = usageStats.currentWeekDCRatio,
              let previous = usageStats.previousWeekDCRatio else {
            return nil
        }

        guard (current - previous) >= Constants.dcIncreaseThreshold else { return nil }

        return DailyInsightOutput(
            id: "dc-increase",
            kind: .dcIncrease,
            text: "Bu hafta DC kullanımın belirgin şekilde arttı.",
            priority: Constants.dcIncreasePriority
        )
    }

    private func savingsTrendInsight(from trendData: DailyInsightTrendData) -> DailyInsightOutput? {
        guard let savingsDelta = trendData.savingsDelta else { return nil }

        if savingsDelta <= -Constants.savingsChangeThreshold {
            return DailyInsightOutput(
                id: "savings-drop",
                kind: .savingsDrop,
                text: "Tasarruf trendin son dönemde zayıfladı.",
                priority: Constants.savingsDropPriority
            )
        }

        if savingsDelta >= Constants.savingsChangeThreshold {
            return DailyInsightOutput(
                id: "savings-increase",
                kind: .savingsIncrease,
                text: "Tasarruf trendin son dönemde güçleniyor.",
                priority: Constants.savingsIncreasePriority
            )
        }

        return nil
    }

    private func expensivePrimaryStationInsight(
        from stationStats: DailyInsightStationStats?
    ) -> DailyInsightOutput? {
        guard let stationStats else { return nil }
        guard stationStats.sessionCount >= Constants.minimumPrimaryStationSessions else { return nil }
        guard stationStats.overallAverageTLPerKWh > 0 else { return nil }

        let premiumRatio = (
            stationStats.averageTLPerKWh - stationStats.overallAverageTLPerKWh
        ) / stationStats.overallAverageTLPerKWh
        guard premiumRatio >= Constants.stationPremiumRatioThreshold else { return nil }

        return DailyInsightOutput(
            id: "expensive-primary-station.\(sanitizeID(stationStats.stationName))",
            kind: .expensivePrimaryStation,
            text: "\(stationStats.stationName) ortalamanın üzerinde pahalı kalıyor.",
            priority: Constants.expensiveStationPriority
        )
    }

    private func chargeRangeInsight(from trendData: DailyInsightTrendData) -> DailyInsightOutput? {
        guard let delta = trendData.averageChargeRangeDelta else { return nil }
        guard abs(delta) >= Constants.chargeRangeChangeThreshold else { return nil }

        let text: String
        if delta > 0 {
            text = "Ortalama şarj aralığın genişledi; maliyetini yeniden dengeleyebilirsin."
        } else {
            text = "Ortalama şarj aralığın daraldı; son dönemde daha kontrollü ilerliyorsun."
        }

        return DailyInsightOutput(
            id: "charge-range-\(delta > 0 ? "widened" : "narrowed")",
            kind: .chargeRangeChanged,
            text: text,
            priority: Constants.chargeRangeChangedPriority
        )
    }

    private func sanitizeID(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(
                of: "[^a-z0-9\\-]",
                with: "",
                options: .regularExpression
            )
    }
}

public struct GenerateDailyInsightSkill {
    private let service: DailyInsightService

    public init(service: DailyInsightService = .init()) {
        self.service = service
    }

    public func generate(input: DailyInsightInput) -> DailyInsightOutput? {
        service.generate(input: input)
    }
}
