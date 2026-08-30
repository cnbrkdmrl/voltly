import Foundation

public enum TrendBreakType: String, Equatable, Sendable {
    case costIncrease = "cost_increase"
    case dcIncrease = "dc_increase"
    case efficiencyDrop = "efficiency_drop"
    case expensiveNewStation = "expensive_new_station"
    case energyChange = "energy_change"
    case durationChange = "duration_change"
    case rangeChange = "range_change"
}

public struct TrendBreakInsight: Equatable, Sendable {
    public let type: TrendBreakType
    public let percentageChange: Double
    public let message: String
    public let priority: Int

    public init(
        type: TrendBreakType,
        percentageChange: Double,
        message: String,
        priority: Int = 0
    ) {
        self.type = type
        self.percentageChange = percentageChange
        self.message = message
        self.priority = priority
    }
}

public struct TrendBreakDetectionInput: Equatable {
    public let recentSessions: [ChargingSession]
    public let baselineSessions: [ChargingSession]
    public let referenceDate: Date

    public init(
        recentSessions: [ChargingSession],
        baselineSessions: [ChargingSession],
        referenceDate: Date
    ) {
        self.recentSessions = recentSessions
        self.baselineSessions = baselineSessions
        self.referenceDate = referenceDate
    }
}

public struct TrendBreakDetectionResult: Equatable {
    public let insights: [TrendBreakInsight]
    public let primaryInsight: TrendBreakInsight?

    public init(insights: [TrendBreakInsight], primaryInsight: TrendBreakInsight?) {
        self.insights = insights
        self.primaryInsight = primaryInsight
    }
}

public struct TrendBreakDetectionService {
    private enum Rules {
        static let minimumTotalSessionCount = 5
        static let minimumWindowSessionCount = 2
        static let minimumMetricSamples = 3

        static let costIncreaseThreshold = 15.0
        static let dcIncreaseThreshold = 20.0
        static let expensiveStationThreshold = 12.0
        static let minimumNewStationSessions = 2

        static let energyChangeThreshold = 18.0
        static let durationChangeThreshold = 20.0
        static let rangeChangeThreshold = 18.0

        static let minimumCostGapTLPerKWh = 0.75
        static let minimumEnergyGapKWh = 2.0
        static let minimumDurationGapMinutes = 8.0
        static let minimumRangeGapPercent = 8.0
    }

    private enum Priority: Int {
        case rangeChange = 180
        case durationChange = 200
        case energyChange = 220
        case efficiencyDrop = 240
        case dcIncrease = 280
        case expensiveNewStation = 320
        case costIncrease = 360
    }

    private let calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase

    public init(
        calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase = .init()
    ) {
        self.calculateEnergyPer100KmUseCase = calculateEnergyPer100KmUseCase
    }

    public func detect(input: TrendBreakDetectionInput) -> TrendBreakDetectionResult {
        guard input.recentSessions.count + input.baselineSessions.count >= Rules.minimumTotalSessionCount,
              input.recentSessions.count >= Rules.minimumWindowSessionCount,
              input.baselineSessions.count >= Rules.minimumWindowSessionCount else {
            return TrendBreakDetectionResult(insights: [], primaryInsight: nil)
        }

        var candidates: [TrendBreakInsight] = []

        if let insight = detectCostIncrease(input: input) {
            candidates.append(insight)
        }
        if let insight = detectDCIncrease(input: input) {
            candidates.append(insight)
        }
        if let insight = detectNewExpensiveStation(input: input) {
            candidates.append(insight)
        }
        if let insight = detectEfficiencyDrop(input: input) {
            candidates.append(insight)
        }
        if let insight = detectAverageEnergyChange(input: input) {
            candidates.append(insight)
        }
        if let insight = detectAverageDurationChange(input: input) {
            candidates.append(insight)
        }
        if let insight = detectAverageRangeChange(input: input) {
            candidates.append(insight)
        }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.percentageChange > rhs.percentageChange
            }
            return lhs.priority > rhs.priority
        }

        return TrendBreakDetectionResult(
            insights: sorted,
            primaryInsight: sorted.first
        )
    }

    private func detectCostIncrease(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        guard let recent = averageTLPerKWh(for: input.recentSessions),
              let baseline = averageTLPerKWh(for: input.baselineSessions),
              baseline > 0 else {
            return nil
        }

        let percentageChange = ((recent - baseline) / baseline) * 100
        let absoluteGap = recent - baseline
        guard percentageChange >= Rules.costIncreaseThreshold,
              absoluteGap >= Rules.minimumCostGapTLPerKWh else {
            return nil
        }

        return TrendBreakInsight(
            type: .costIncrease,
            percentageChange: percentageChange,
            message: "Son 2 haftada maliyetin %\(Int(percentageChange.rounded())) arttı.",
            priority: Priority.costIncrease.rawValue
        )
    }

    private func detectDCIncrease(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        guard let recent = dcUsageRatio(for: input.recentSessions),
              let baseline = dcUsageRatio(for: input.baselineSessions) else {
            return nil
        }

        let percentageChange = recent - baseline
        guard percentageChange >= Rules.dcIncreaseThreshold else { return nil }

        return TrendBreakInsight(
            type: .dcIncrease,
            percentageChange: percentageChange,
            message: "Son dönemde DC kullanım oranın %\(Int(percentageChange.rounded())) arttı.",
            priority: Priority.dcIncrease.rawValue
        )
    }

    private func detectNewExpensiveStation(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        let recentEntries = stationCostEntries(from: input.recentSessions)
        let baselineEntries = stationCostEntries(from: input.baselineSessions)

        guard !recentEntries.isEmpty else { return nil }
        let baselineNames = Set(baselineEntries.map(\.name))
        let recentOverallAverage = recentEntries.map(\.tlPerKWh).reduce(0, +) / Double(recentEntries.count)

        let groupedRecent = Dictionary(grouping: recentEntries, by: \.name)
        let candidate = groupedRecent
            .filter { !baselineNames.contains($0.key) && $0.value.count >= Rules.minimumNewStationSessions }
            .compactMap { name, entries -> (String, Double, Double)? in
                let stationAverage = entries.map(\.tlPerKWh).reduce(0, +) / Double(entries.count)
                let gap = stationAverage - recentOverallAverage
                guard recentOverallAverage > 0 else { return nil }
                let premiumPercent = (gap / recentOverallAverage) * 100
                guard premiumPercent >= Rules.expensiveStationThreshold,
                      gap >= Rules.minimumCostGapTLPerKWh else {
                    return nil
                }
                return (name, premiumPercent, gap)
            }
            .max { lhs, rhs in lhs.1 < rhs.1 }

        guard let (stationName, premiumPercent, _) = candidate else { return nil }

        return TrendBreakInsight(
            type: .expensiveNewStation,
            percentageChange: premiumPercent,
            message: "Yeni kullandığın \(stationName) istasyonu ortalamandan daha pahalı.",
            priority: Priority.expensiveNewStation.rawValue
        )
    }

    private func detectEfficiencyDrop(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        guard let recent = calculateEnergyPer100KmUseCase.execute(sessions: input.recentSessions)?.value,
              let baseline = calculateEnergyPer100KmUseCase.execute(sessions: input.baselineSessions)?.value,
              baseline > 0,
              recent > baseline else {
            return nil
        }

        let percentageChange = ((recent - baseline) / baseline) * 100
        guard percentageChange >= Rules.energyChangeThreshold else { return nil }

        return TrendBreakInsight(
            type: .efficiencyDrop,
            percentageChange: percentageChange,
            message: "Verimliliğin %\(Int(percentageChange.rounded())) geriledi.",
            priority: Priority.efficiencyDrop.rawValue
        )
    }

    private func detectAverageEnergyChange(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        detectAverageDelta(
            recentSessions: input.recentSessions,
            baselineSessions: input.baselineSessions,
            thresholdPercent: Rules.energyChangeThreshold,
            minimumAbsoluteGap: Rules.minimumEnergyGapKWh
        ) { $0.energyKWh }
        .map { percentageChange in
            let text: String
            if percentageChange > 0 {
                text = "Ortalama enerji tüketimin %\(Int(percentageChange.rounded())) arttı."
            } else {
                text = "Ortalama enerji tüketimin %\(Int(abs(percentageChange).rounded())) azaldı."
            }
            return TrendBreakInsight(
                type: .energyChange,
                percentageChange: abs(percentageChange),
                message: text,
                priority: Priority.energyChange.rawValue
            )
        }
    }

    private func detectAverageDurationChange(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        detectAverageDelta(
            recentSessions: input.recentSessions,
            baselineSessions: input.baselineSessions,
            thresholdPercent: Rules.durationChangeThreshold,
            minimumAbsoluteGap: Rules.minimumDurationGapMinutes
        ) { session in
            guard let duration = session.durationMin else { return nil }
            return Double(duration)
        }
        .map { percentageChange in
            let text: String
            if percentageChange > 0 {
                text = "Ortalama şarj süren %\(Int(percentageChange.rounded())) uzadı."
            } else {
                text = "Ortalama şarj süren %\(Int(abs(percentageChange).rounded())) kısaldı."
            }
            return TrendBreakInsight(
                type: .durationChange,
                percentageChange: abs(percentageChange),
                message: text,
                priority: Priority.durationChange.rawValue
            )
        }
    }

    private func detectAverageRangeChange(input: TrendBreakDetectionInput) -> TrendBreakInsight? {
        detectAverageDelta(
            recentSessions: input.recentSessions,
            baselineSessions: input.baselineSessions,
            thresholdPercent: Rules.rangeChangeThreshold,
            minimumAbsoluteGap: Rules.minimumRangeGapPercent
        ) { session in
            guard session.socEnd > session.socStart else { return nil }
            return session.socEnd - session.socStart
        }
        .map { percentageChange in
            let text: String
            if percentageChange > 0 {
                text = "Ortalama şarj aralığın %\(Int(percentageChange.rounded())) genişledi."
            } else {
                text = "Ortalama şarj aralığın %\(Int(abs(percentageChange).rounded())) daraldı."
            }
            return TrendBreakInsight(
                type: .rangeChange,
                percentageChange: abs(percentageChange),
                message: text,
                priority: Priority.rangeChange.rawValue
            )
        }
    }

    private func detectAverageDelta(
        recentSessions: [ChargingSession],
        baselineSessions: [ChargingSession],
        thresholdPercent: Double,
        minimumAbsoluteGap: Double,
        value: (ChargingSession) -> Double?
    ) -> Double? {
        let recentValues = recentSessions.compactMap(value).filter { $0 > 0 }
        let baselineValues = baselineSessions.compactMap(value).filter { $0 > 0 }

        guard recentValues.count >= Rules.minimumMetricSamples,
              baselineValues.count >= Rules.minimumMetricSamples else {
            return nil
        }

        let recentAverage = recentValues.reduce(0, +) / Double(recentValues.count)
        let baselineAverage = baselineValues.reduce(0, +) / Double(baselineValues.count)
        guard baselineAverage > 0 else { return nil }

        let absoluteGap = recentAverage - baselineAverage
        let percentageChange = (absoluteGap / baselineAverage) * 100
        guard abs(percentageChange) >= thresholdPercent,
              abs(absoluteGap) >= minimumAbsoluteGap else {
            return nil
        }

        return percentageChange
    }

    private func averageTLPerKWh(for sessions: [ChargingSession]) -> Double? {
        let values = sessions.compactMap(\.tlPerKWh)
        guard values.count >= Rules.minimumWindowSessionCount else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func dcUsageRatio(for sessions: [ChargingSession]) -> Double? {
        guard sessions.count >= Rules.minimumWindowSessionCount else { return nil }
        let dcCount = sessions.filter { $0.chargeMethod == .publicDC }.count
        return (Double(dcCount) / Double(sessions.count)) * 100
    }

    private func stationCostEntries(from sessions: [ChargingSession]) -> [(name: String, tlPerKWh: Double)] {
        sessions.compactMap { session in
            guard session.chargeMethod != .home,
                  let tlPerKWh = session.tlPerKWh else {
                return nil
            }

            let station = session.stationDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !station.isEmpty, station != "Konum yok" else { return nil }
            return (station, tlPerKWh)
        }
    }
}

public struct DetectTrendBreakInput: Equatable {
    public let last30Days: [ChargingSession]
    public let previous30Days: [ChargingSession]

    public init(last30Days: [ChargingSession], previous30Days: [ChargingSession]) {
        self.last30Days = last30Days
        self.previous30Days = previous30Days
    }
}

public struct DetectTrendBreakSkill {
    private let trendBreakDetectionService: TrendBreakDetectionService

    public init(
        calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase = .init(),
        trendBreakDetectionService: TrendBreakDetectionService? = nil
    ) {
        self.trendBreakDetectionService = trendBreakDetectionService ?? TrendBreakDetectionService(
            calculateEnergyPer100KmUseCase: calculateEnergyPer100KmUseCase
        )
    }

    public func detect(input: DetectTrendBreakInput) -> TrendBreakInsight? {
        let referenceDate = input.last30Days.map(\.sessionDate).max() ?? .now
        let result = trendBreakDetectionService.detect(
            input: TrendBreakDetectionInput(
                recentSessions: input.last30Days,
                baselineSessions: input.previous30Days,
                referenceDate: referenceDate
            )
        )
        return result.primaryInsight
    }
}
