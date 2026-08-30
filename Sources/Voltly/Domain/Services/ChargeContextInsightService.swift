import Foundation

public struct ChargeContextInsight: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let iconName: String

    public init(id: String, title: String, detail: String, iconName: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.iconName = iconName
    }
}

public struct ChargeContextInsightService {
    private enum Constants {
        static let minimumTotalTaggedSessions = 5
        static let minimumGroupCount = 2
        static let longRoadConsumptionThreshold = 10.0
        static let temperatureCostIncreaseThreshold = 8.0
    }

    private let calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase
    private let calculateTLPerKWhUseCase: CalculateTLPerKWhUseCase

    public init(
        calculateEnergyPer100KmUseCase: CalculateEnergyPer100KmUseCase = .init(),
        calculateTLPerKWhUseCase: CalculateTLPerKWhUseCase = .init()
    ) {
        self.calculateEnergyPer100KmUseCase = calculateEnergyPer100KmUseCase
        self.calculateTLPerKWhUseCase = calculateTLPerKWhUseCase
    }

    public func generateInsights(from sessions: [ChargingSession]) -> [ChargeContextInsight] {
        let taggedSessions = sessions.filter { !$0.contextTags.isEmpty }
        guard taggedSessions.count >= Constants.minimumTotalTaggedSessions else {
            return []
        }

        var insights: [ChargeContextInsight] = []

        if let longRoadInsight = makeLongRoadInsight(from: taggedSessions) {
            insights.append(longRoadInsight)
        }

        if let coldWeatherInsight = makeTemperatureCostInsight(
            taggedSessions: taggedSessions,
            tag: .coldWeather,
            title: "Soguk hava etkisi",
            messagePrefix: "Soguk havada ortalama maliyet"
        ) {
            insights.append(coldWeatherInsight)
        }

        if let hotWeatherInsight = makeTemperatureCostInsight(
            taggedSessions: taggedSessions,
            tag: .hotWeather,
            title: "Sicak hava etkisi",
            messagePrefix: "Sicak havada ortalama maliyet"
        ) {
            insights.append(hotWeatherInsight)
        }

        return insights
    }

    private func makeLongRoadInsight(from sessions: [ChargingSession]) -> ChargeContextInsight? {
        let longRoadSessions = sessions.filter { $0.contextTags.contains(.longRoad) }
        let citySessions = sessions.filter { $0.contextTags.contains(.cityDriving) }

        guard longRoadSessions.count >= Constants.minimumGroupCount,
              citySessions.count >= Constants.minimumGroupCount,
              let longRoadConsumption = calculateEnergyPer100KmUseCase.execute(sessions: longRoadSessions)?.value,
              let cityConsumption = calculateEnergyPer100KmUseCase.execute(sessions: citySessions)?.value,
              cityConsumption > 0 else {
            return nil
        }

        let increase = ((longRoadConsumption - cityConsumption) / cityConsumption) * 100
        guard increase >= Constants.longRoadConsumptionThreshold else {
            return nil
        }

        return ChargeContextInsight(
            id: "context.long_road_consumption",
            title: "Uzun yol etkisi",
            detail: "Uzun yolda tuketimin sehir icine gore \(NumberFormatting.percent(increase)) daha yuksek.",
            iconName: "road.lanes"
        )
    }

    private func makeTemperatureCostInsight(
        taggedSessions: [ChargingSession],
        tag: ChargeContextTag,
        title: String,
        messagePrefix: String
    ) -> ChargeContextInsight? {
        let taggedGroup = taggedSessions.filter { $0.contextTags.contains(tag) }
        let comparisonGroup = taggedSessions.filter { !$0.contextTags.contains(tag) }

        guard taggedGroup.count >= Constants.minimumGroupCount,
              comparisonGroup.count >= Constants.minimumGroupCount,
              let taggedAverage = averageTLPerKWh(for: taggedGroup),
              let comparisonAverage = averageTLPerKWh(for: comparisonGroup),
              comparisonAverage > 0 else {
            return nil
        }

        let increase = ((taggedAverage - comparisonAverage) / comparisonAverage) * 100
        guard increase >= Constants.temperatureCostIncreaseThreshold else {
            return nil
        }

        return ChargeContextInsight(
            id: "context.\(tag.rawValue)_cost",
            title: title,
            detail: "\(messagePrefix) \(NumberFormatting.percent(increase)) artiyor.",
            iconName: tag == .coldWeather ? "snowflake" : "sun.max"
        )
    }

    private func averageTLPerKWh(for sessions: [ChargingSession]) -> Double? {
        let values = sessions.compactMap { session -> Double? in
            guard let energy = session.energyKWh else { return nil }
            return calculateTLPerKWhUseCase.execute(priceTotal: session.priceTotal, energyKWh: energy)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
