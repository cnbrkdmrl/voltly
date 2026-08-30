import Foundation

public enum SmartFavoriteStationCategory: String, CaseIterable, Equatable {
    case mostUsed
    case cheapest
    case mostEfficient

    public var titleTR: String {
        switch self {
        case .mostUsed:
            return "En sık kullandığın"
        case .cheapest:
            return "En uygun maliyetli"
        case .mostEfficient:
            return "En verimli"
        }
    }
}

public struct SmartFavoriteStationSuggestion: Identifiable, Equatable {
    public let id: String
    public let category: SmartFavoriteStationCategory
    public let stationBrand: String?
    public let locationName: String?
    public let displayName: String
    public let suggestedChargeMethod: ChargeMethod
    public let sessionCount: Int
    public let averageTLPerKWh: Double?
    public let averageTLPer100Km: Double?
    public let averageEnergyPer100Km: Double?

    public init(
        id: String,
        category: SmartFavoriteStationCategory,
        stationBrand: String?,
        locationName: String?,
        displayName: String,
        suggestedChargeMethod: ChargeMethod,
        sessionCount: Int,
        averageTLPerKWh: Double?,
        averageTLPer100Km: Double?,
        averageEnergyPer100Km: Double?
    ) {
        self.id = id
        self.category = category
        self.stationBrand = stationBrand
        self.locationName = locationName
        self.displayName = displayName
        self.suggestedChargeMethod = suggestedChargeMethod
        self.sessionCount = sessionCount
        self.averageTLPerKWh = averageTLPerKWh
        self.averageTLPer100Km = averageTLPer100Km
        self.averageEnergyPer100Km = averageEnergyPer100Km
    }
}

public struct SmartFavoriteStationReport: Equatable {
    public let suggestions: [SmartFavoriteStationSuggestion]

    public init(suggestions: [SmartFavoriteStationSuggestion]) {
        self.suggestions = suggestions
    }
}

public struct SmartFavoriteStationService {
    private enum Constants {
        static let minimumMostUsedSessions = 2
        static let minimumStationPriceSamples = 2
        static let minimumStationEfficiencySamples = 2
        static let minimumComparableStations = 2

        static let minimumPlausibleKWhPer100Km = 8.0
        static let maximumPlausibleKWhPer100Km = 40.0
        static let maximumDistancePerSessionKM = 2_500.0
        static let maximumDistancePerDayKM = 1_200.0
    }

    public init() {}

    public func makeReport(
        sessions: [ChargingSession]
    ) -> SmartFavoriteStationReport? {
        let stationSessions = sessions
            .filter { $0.chargeMethod != .home }
            .compactMap(stationSession(from:))

        guard !stationSessions.isEmpty else { return nil }
        let groupedByStation = Dictionary(grouping: stationSessions, by: \.stationKey)

        var suggestions: [SmartFavoriteStationSuggestion] = []

        if let mostUsed = buildMostUsedSuggestion(from: groupedByStation) {
            suggestions.append(mostUsed)
        }
        if let cheapest = buildCheapestSuggestion(from: groupedByStation) {
            suggestions.append(cheapest)
        }
        if let mostEfficient = buildMostEfficientSuggestion(
            stationSessions: stationSessions,
            groupedByStation: groupedByStation
        ) {
            suggestions.append(mostEfficient)
        }

        guard !suggestions.isEmpty else { return nil }

        let ordered = SmartFavoriteStationCategory.allCases.compactMap { category in
            suggestions.first(where: { $0.category == category })
        }
        return SmartFavoriteStationReport(suggestions: ordered)
    }

    private func buildMostUsedSuggestion(
        from groupedByStation: [StationKey: [StationSession]]
    ) -> SmartFavoriteStationSuggestion? {
        let top = groupedByStation
            .compactMap { stationKey, stationSessions -> (StationKey, [StationSession], Date)? in
                guard stationSessions.count >= Constants.minimumMostUsedSessions else { return nil }
                let latestDate = stationSessions.map(\.session.sessionDate).max() ?? .distantPast
                return (stationKey, stationSessions, latestDate)
            }
            .sorted { lhs, rhs in
                if lhs.1.count == rhs.1.count {
                    return lhs.2 > rhs.2
                }
                return lhs.1.count > rhs.1.count
            }
            .first

        guard let top else { return nil }
        let averageTLPerKWh = top.1.compactMap(\.session.tlPerKWh).average
        return makeSuggestion(
            category: .mostUsed,
            stationKey: top.0,
            stationSessions: top.1,
            averageTLPerKWh: averageTLPerKWh,
            averageTLPer100Km: nil,
            averageEnergyPer100Km: nil
        )
    }

    private func buildCheapestSuggestion(
        from groupedByStation: [StationKey: [StationSession]]
    ) -> SmartFavoriteStationSuggestion? {
        let candidates = groupedByStation.compactMap { stationKey, stationSessions -> (StationKey, [StationSession], Double)? in
            let validTLPerKWh = stationSessions.compactMap(\.session.tlPerKWh)
            guard validTLPerKWh.count >= Constants.minimumStationPriceSamples else { return nil }
            let average = validTLPerKWh.reduce(0, +) / Double(validTLPerKWh.count)
            return (stationKey, stationSessions, average)
        }

        guard candidates.count >= Constants.minimumComparableStations else { return nil }
        guard let cheapest = candidates.min(by: { $0.2 < $1.2 }) else { return nil }

        return makeSuggestion(
            category: .cheapest,
            stationKey: cheapest.0,
            stationSessions: cheapest.1,
            averageTLPerKWh: cheapest.2,
            averageTLPer100Km: nil,
            averageEnergyPer100Km: nil
        )
    }

    private func buildMostEfficientSuggestion(
        stationSessions: [StationSession],
        groupedByStation: [StationKey: [StationSession]]
    ) -> SmartFavoriteStationSuggestion? {
        let metricsByStation = efficiencyMetricsByStation(from: stationSessions)

        let tlPer100KmCandidates = metricsByStation.compactMap { stationKey, metrics -> (StationKey, [StationSession], Double)? in
            guard let group = groupedByStation[stationKey] else { return nil }
            guard metrics.tlPer100KmValues.count >= Constants.minimumStationEfficiencySamples else {
                return nil
            }
            let average = metrics.tlPer100KmValues.reduce(0, +) / Double(metrics.tlPer100KmValues.count)
            return (stationKey, group, average)
        }

        if tlPer100KmCandidates.count >= Constants.minimumComparableStations,
           let bestTLPer100Km = tlPer100KmCandidates.min(by: { $0.2 < $1.2 }) {
            return makeSuggestion(
                category: .mostEfficient,
                stationKey: bestTLPer100Km.0,
                stationSessions: bestTLPer100Km.1,
                averageTLPerKWh: nil,
                averageTLPer100Km: bestTLPer100Km.2,
                averageEnergyPer100Km: nil
            )
        }

        let energyPer100KmCandidates = metricsByStation.compactMap { stationKey, metrics -> (StationKey, [StationSession], Double)? in
            guard let group = groupedByStation[stationKey] else { return nil }
            guard metrics.energyPer100KmValues.count >= Constants.minimumStationEfficiencySamples else {
                return nil
            }
            let average = metrics.energyPer100KmValues.reduce(0, +) / Double(metrics.energyPer100KmValues.count)
            return (stationKey, group, average)
        }

        guard energyPer100KmCandidates.count >= Constants.minimumComparableStations,
              let bestEnergyPer100Km = energyPer100KmCandidates.min(by: { $0.2 < $1.2 }) else {
            return nil
        }

        return makeSuggestion(
            category: .mostEfficient,
            stationKey: bestEnergyPer100Km.0,
            stationSessions: bestEnergyPer100Km.1,
            averageTLPerKWh: nil,
            averageTLPer100Km: nil,
            averageEnergyPer100Km: bestEnergyPer100Km.2
        )
    }

    private func makeSuggestion(
        category: SmartFavoriteStationCategory,
        stationKey: StationKey,
        stationSessions: [StationSession],
        averageTLPerKWh: Double?,
        averageTLPer100Km: Double?,
        averageEnergyPer100Km: Double?
    ) -> SmartFavoriteStationSuggestion {
        let latestSession = stationSessions.max(by: { $0.session.sessionDate < $1.session.sessionDate })
        let suggestedChargeMethod = dominantMethod(from: stationSessions.map(\.session.chargeMethod))
        let stationBrand = latestSession?.stationBrand
        let locationName = latestSession?.locationName

        return SmartFavoriteStationSuggestion(
            id: "\(category.rawValue)|\(stationKey.composite)",
            category: category,
            stationBrand: stationBrand,
            locationName: locationName,
            displayName: StationKey.displayName(brand: stationBrand, location: locationName),
            suggestedChargeMethod: suggestedChargeMethod,
            sessionCount: stationSessions.count,
            averageTLPerKWh: averageTLPerKWh,
            averageTLPer100Km: averageTLPer100Km,
            averageEnergyPer100Km: averageEnergyPer100Km
        )
    }

    private func efficiencyMetricsByStation(
        from stationSessions: [StationSession]
    ) -> [StationKey: StationEfficiencyMetrics] {
        let sorted = stationSessions.sorted { $0.session.sessionDate < $1.session.sessionDate }
        var previousOdometerSession: ChargingSession?
        var metricsByStation: [StationKey: StationEfficiencyMetrics] = [:]

        for item in sorted {
            defer {
                if item.session.odometerKM != nil {
                    previousOdometerSession = item.session
                }
            }

            guard let metric = efficiencyMetric(
                session: item.session,
                previousOdometerSession: previousOdometerSession
            ) else {
                continue
            }

            var existing = metricsByStation[item.stationKey] ?? StationEfficiencyMetrics()
            existing.energyPer100KmValues.append(metric.energyPer100Km)
            if let tlPer100Km = metric.tlPer100Km {
                existing.tlPer100KmValues.append(tlPer100Km)
            }
            metricsByStation[item.stationKey] = existing
        }

        return metricsByStation
    }

    private func efficiencyMetric(
        session: ChargingSession,
        previousOdometerSession: ChargingSession?
    ) -> SessionEfficiencyMetric? {
        guard let previousOdometerSession,
              let currentOdometer = session.odometerKM,
              let previousOdometer = previousOdometerSession.odometerKM,
              let energy = session.energyKWh,
              energy > 0 else {
            return nil
        }

        let distance = currentOdometer - previousOdometer
        guard isPlausibleDistance(
            distance,
            from: previousOdometerSession.sessionDate,
            to: session.sessionDate
        ) else {
            return nil
        }

        let energyPer100Km = (energy / distance) * 100
        guard isPlausibleEnergyPer100Km(energyPer100Km) else { return nil }

        let tlPer100Km = session.tlPerKWh.map { $0 * energyPer100Km }
        return SessionEfficiencyMetric(
            energyPer100Km: energyPer100Km,
            tlPer100Km: tlPer100Km
        )
    }

    private func isPlausibleDistance(
        _ distance: Double,
        from startDate: Date,
        to endDate: Date
    ) -> Bool {
        guard distance > 0, distance <= Constants.maximumDistancePerSessionKM else {
            return false
        }

        let interval = max(endDate.timeIntervalSince(startDate), 3_600)
        let days = interval / 86_400
        let maxPlausibleDistance = max(
            Constants.maximumDistancePerDayKM,
            days * Constants.maximumDistancePerDayKM
        )
        return distance <= maxPlausibleDistance
    }

    private func isPlausibleEnergyPer100Km(_ value: Double) -> Bool {
        (Constants.minimumPlausibleKWhPer100Km...Constants.maximumPlausibleKWhPer100Km).contains(value)
    }

    private func dominantMethod(from methods: [ChargeMethod]) -> ChargeMethod {
        let counts = methods.reduce(into: [ChargeMethod: Int]()) { partialResult, method in
            partialResult[method, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return methodPriority(lhs.key) < methodPriority(rhs.key)
                }
                return lhs.value > rhs.value
            }
            .first?.key ?? .publicAC
    }

    private func methodPriority(_ method: ChargeMethod) -> Int {
        switch method {
        case .publicAC:
            return 0
        case .publicDC:
            return 1
        case .home:
            return 2
        }
    }

    private func stationSession(from session: ChargingSession) -> StationSession? {
        let brand = trimmed(session.stationBrand)
        let location = trimmed(session.locationName)
        let stationKey = StationKey(
            brand: normalize(brand),
            location: normalize(location)
        )

        guard stationKey.hasMeaningfulValue else { return nil }

        return StationSession(
            session: session,
            stationKey: stationKey,
            stationBrand: brand.isEmpty ? nil : brand,
            locationName: location.isEmpty ? nil : location
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased()
    }

    private func trimmed(_ text: String?) -> String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private struct SessionEfficiencyMetric {
    let energyPer100Km: Double
    let tlPer100Km: Double?
}

private struct StationEfficiencyMetrics {
    var tlPer100KmValues: [Double] = []
    var energyPer100KmValues: [Double] = []
}

private struct StationSession {
    let session: ChargingSession
    let stationKey: StationKey
    let stationBrand: String?
    let locationName: String?
}

private struct StationKey: Hashable {
    let brand: String
    let location: String

    var hasMeaningfulValue: Bool {
        !brand.isEmpty || !location.isEmpty
    }

    var composite: String {
        "\(brand)|\(location)"
    }

    static func displayName(brand: String?, location: String?) -> String {
        let safeBrand = brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !safeBrand.isEmpty, !safeLocation.isEmpty {
            return "\(safeBrand) • \(safeLocation)"
        }
        if !safeBrand.isEmpty {
            return safeBrand
        }
        if !safeLocation.isEmpty {
            return safeLocation
        }
        return "Bilinmeyen istasyon"
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
