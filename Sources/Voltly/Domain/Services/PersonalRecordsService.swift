import Foundation

public enum PersonalRecordType: String, CaseIterable, Identifiable, Equatable, Sendable {
    case cheapestCharge
    case mostExpensiveCharge
    case mostEfficientCharge
    case highestEnergySession
    case shortestSession
    case longestSession

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cheapestCharge:
            return "En ucuz sarj"
        case .mostExpensiveCharge:
            return "En pahali sarj"
        case .mostEfficientCharge:
            return "En verimli sarj"
        case .highestEnergySession:
            return "En yuksek enerji"
        case .shortestSession:
            return "En kisa seans"
        case .longestSession:
            return "En uzun seans"
        }
    }

    public var iconName: String {
        switch self {
        case .cheapestCharge:
            return "arrow.down.circle.fill"
        case .mostExpensiveCharge:
            return "arrow.up.circle.fill"
        case .mostEfficientCharge:
            return "leaf.fill"
        case .highestEnergySession:
            return "bolt.fill"
        case .shortestSession:
            return "clock.arrow.2.circlepath"
        case .longestSession:
            return "clock.fill"
        }
    }
}

public struct PersonalRecordSharePayload: Equatable, Sendable {
    public let recordType: PersonalRecordType
    public let title: String
    public let headline: String
    public let detail: String
    public let sessionID: UUID
    public let generatedAt: Date
    public let source: AnalysisDataSourceKind
    public let confidenceScore: Int

    public init(
        recordType: PersonalRecordType,
        title: String,
        headline: String,
        detail: String,
        sessionID: UUID,
        generatedAt: Date,
        source: AnalysisDataSourceKind,
        confidenceScore: Int
    ) {
        self.recordType = recordType
        self.title = title
        self.headline = headline
        self.detail = detail
        self.sessionID = sessionID
        self.generatedAt = generatedAt
        self.source = source
        self.confidenceScore = confidenceScore
    }
}

public struct PersonalRecordItem: Identifiable, Equatable {
    public let type: PersonalRecordType
    public let session: ChargingSession
    public let metricValue: Double
    public let metricText: String
    public let subtitle: String
    public let note: String?
    public let confidence: DataConfidenceScore
    public let sharePayload: PersonalRecordSharePayload

    public var id: String { type.id }

    public init(
        type: PersonalRecordType,
        session: ChargingSession,
        metricValue: Double,
        metricText: String,
        subtitle: String,
        note: String?,
        confidence: DataConfidenceScore,
        sharePayload: PersonalRecordSharePayload
    ) {
        self.type = type
        self.session = session
        self.metricValue = metricValue
        self.metricText = metricText
        self.subtitle = subtitle
        self.note = note
        self.confidence = confidence
        self.sharePayload = sharePayload
    }
}

public struct PersonalRecordsService {
    private enum Constants {
        static let minEnergyKWh = 1.0
        static let maxEnergyKWh = 250.0
        static let minTLPerKWh = 0.5
        static let maxTLPerKWh = 40.0
        static let minTLPer100Km = 5.0
        static let maxTLPer100Km = 250.0
        static let minDurationMinutes = 5
        static let maxDurationMinutes = 24 * 60
        static let maxDistancePerSessionKM = 2_500.0
    }

    private struct MetricCandidate {
        let session: ChargingSession
        let value: Double
        let source: AnalysisDataSourceKind
        let sampleCount: Int
        let exactSampleCount: Int
        let estimatedSampleCount: Int
        let missingSampleCount: Int
    }

    private let calculateTLPerKWhUseCase: CalculateTLPerKWhUseCase

    public init(
        calculateTLPerKWhUseCase: CalculateTLPerKWhUseCase = .init()
    ) {
        self.calculateTLPerKWhUseCase = calculateTLPerKWhUseCase
    }

    public func generateRecords(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) -> [PersonalRecordItem] {
        let sortedSessions = sessions.sorted { $0.sessionDate < $1.sessionDate }
        guard !sortedSessions.isEmpty else { return [] }

        var records: [PersonalRecordItem] = []

        if let cheapest = tlPerKWhCandidates(from: sortedSessions).min(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .cheapestCharge,
                    candidate: cheapest,
                    metricText: NumberFormatting.tlPerKWh(
                        cheapest.value,
                        currencyCode: cheapest.session.currencyCode
                    ),
                    note: note(for: cheapest.source),
                    referenceDate: referenceDate
                )
            )
        }

        if let expensive = tlPerKWhCandidates(from: sortedSessions).max(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .mostExpensiveCharge,
                    candidate: expensive,
                    metricText: NumberFormatting.tlPerKWh(
                        expensive.value,
                        currencyCode: expensive.session.currencyCode
                    ),
                    note: note(for: expensive.source),
                    referenceDate: referenceDate
                )
            )
        }

        let efficiencyPool = efficiencyCandidates(vehicle: vehicle, sessions: sortedSessions)
        let preferredEfficiencyPool = efficiencyPool.filter { $0.source != .estimated }
        let selectedEfficiencyPool = preferredEfficiencyPool.isEmpty ? efficiencyPool : preferredEfficiencyPool

        if let efficient = selectedEfficiencyPool.min(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .mostEfficientCharge,
                    candidate: efficient,
                    metricText: "\(NumberFormatting.currency(efficient.value, code: efficient.session.currencyCode))/100 km",
                    note: note(for: efficient.source),
                    referenceDate: referenceDate
                )
            )
        }

        if let highestEnergy = energyCandidates(from: sortedSessions).max(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .highestEnergySession,
                    candidate: highestEnergy,
                    metricText: NumberFormatting.kWh(highestEnergy.value),
                    note: note(for: highestEnergy.source),
                    referenceDate: referenceDate
                )
            )
        }

        if let shortest = durationCandidates(from: sortedSessions).min(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .shortestSession,
                    candidate: shortest,
                    metricText: "\(Int(shortest.value.rounded())) dk",
                    note: nil,
                    referenceDate: referenceDate
                )
            )
        }

        if let longest = durationCandidates(from: sortedSessions).max(by: { $0.value < $1.value }) {
            records.append(
                makeRecord(
                    type: .longestSession,
                    candidate: longest,
                    metricText: "\(Int(longest.value.rounded())) dk",
                    note: nil,
                    referenceDate: referenceDate
                )
            )
        }

        let order = PersonalRecordType.allCases
        return records.sorted { lhs, rhs in
            let lhsOrder = order.firstIndex(of: lhs.type) ?? .max
            let rhsOrder = order.firstIndex(of: rhs.type) ?? .max
            return lhsOrder < rhsOrder
        }
    }

    private func tlPerKWhCandidates(from sessions: [ChargingSession]) -> [MetricCandidate] {
        sessions.compactMap { session in
            guard session.priceTotal > 0,
                  let energy = session.energyKWh,
                  energy >= Constants.minEnergyKWh,
                  energy <= Constants.maxEnergyKWh,
                  let tlPerKWh = calculateTLPerKWhUseCase.execute(
                    priceTotal: session.priceTotal,
                    energyKWh: energy
                  ),
                  tlPerKWh >= Constants.minTLPerKWh,
                  tlPerKWh <= Constants.maxTLPerKWh else {
                return nil
            }

            return MetricCandidate(
                session: session,
                value: tlPerKWh,
                source: session.energyIsEstimated ? .mixed : .real,
                sampleCount: 1,
                exactSampleCount: session.energyIsEstimated ? 0 : 1,
                estimatedSampleCount: session.energyIsEstimated ? 1 : 0,
                missingSampleCount: 0
            )
        }
    }

    private func efficiencyCandidates(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> [MetricCandidate] {
        var candidates: [MetricCandidate] = []
        var previousOdometerSession: ChargingSession?

        for session in sessions {
            defer {
                if session.odometerKM != nil {
                    previousOdometerSession = session
                }
            }

            guard let tlPerKWh = validTLPerKWh(for: session) else { continue }

            if let candidate = exactEfficiencyCandidate(
                session: session,
                previousOdometerSession: previousOdometerSession,
                tlPerKWh: tlPerKWh,
                sessionCount: sessions.count
            ) {
                candidates.append(candidate)
                continue
            }

            guard let factoryConsumption = vehicle.factoryConsumptionKWh100km,
                  factoryConsumption > 0 else {
                continue
            }

            let tlPer100Km = tlPerKWh * factoryConsumption
            guard tlPer100Km >= Constants.minTLPer100Km,
                  tlPer100Km <= Constants.maxTLPer100Km else {
                continue
            }

            candidates.append(
                MetricCandidate(
                    session: session,
                    value: tlPer100Km,
                    source: .estimated,
                    sampleCount: 1,
                    exactSampleCount: 0,
                    estimatedSampleCount: 1,
                    missingSampleCount: max(sessions.count - 1, 0)
                )
            )
        }

        return candidates
    }

    private func exactEfficiencyCandidate(
        session: ChargingSession,
        previousOdometerSession: ChargingSession?,
        tlPerKWh: Double,
        sessionCount: Int
    ) -> MetricCandidate? {
        guard let currentOdometer = session.odometerKM,
              let previousOdometerSession,
              let previousOdometer = previousOdometerSession.odometerKM,
              let energy = session.energyKWh,
              energy > 0 else {
            return nil
        }

        let distance = currentOdometer - previousOdometer
        guard distance > 0, distance <= Constants.maxDistancePerSessionKM else {
            return nil
        }

        let consumption = (energy / distance) * 100
        let tlPer100Km = tlPerKWh * consumption
        guard tlPer100Km >= Constants.minTLPer100Km,
              tlPer100Km <= Constants.maxTLPer100Km else {
            return nil
        }

        return MetricCandidate(
            session: session,
            value: tlPer100Km,
            source: session.energyIsEstimated ? .mixed : .real,
            sampleCount: 2,
            exactSampleCount: session.energyIsEstimated ? 1 : 2,
            estimatedSampleCount: session.energyIsEstimated ? 1 : 0,
            missingSampleCount: max(sessionCount - 2, 0)
        )
    }

    private func energyCandidates(from sessions: [ChargingSession]) -> [MetricCandidate] {
        sessions.compactMap { session in
            guard let energy = session.energyKWh,
                  energy >= Constants.minEnergyKWh,
                  energy <= Constants.maxEnergyKWh else {
                return nil
            }

            let source: AnalysisDataSourceKind = session.energyIsEstimated ? .estimated : .real

            return MetricCandidate(
                session: session,
                value: energy,
                source: source,
                sampleCount: 1,
                exactSampleCount: source == .real ? 1 : 0,
                estimatedSampleCount: source == .estimated ? 1 : 0,
                missingSampleCount: 0
            )
        }
    }

    private func durationCandidates(from sessions: [ChargingSession]) -> [MetricCandidate] {
        sessions.compactMap { session in
            guard let duration = session.durationMin,
                  duration >= Constants.minDurationMinutes,
                  duration <= Constants.maxDurationMinutes else {
                return nil
            }

            return MetricCandidate(
                session: session,
                value: Double(duration),
                source: .real,
                sampleCount: 1,
                exactSampleCount: 1,
                estimatedSampleCount: 0,
                missingSampleCount: 0
            )
        }
    }

    private func validTLPerKWh(for session: ChargingSession) -> Double? {
        guard session.priceTotal > 0,
              let energy = session.energyKWh,
              energy >= Constants.minEnergyKWh,
              energy <= Constants.maxEnergyKWh,
              let tlPerKWh = calculateTLPerKWhUseCase.execute(priceTotal: session.priceTotal, energyKWh: energy),
              tlPerKWh >= Constants.minTLPerKWh,
              tlPerKWh <= Constants.maxTLPerKWh else {
            return nil
        }
        return tlPerKWh
    }

    private func makeRecord(
        type: PersonalRecordType,
        candidate: MetricCandidate,
        metricText: String,
        note: String?,
        referenceDate: Date
    ) -> PersonalRecordItem {
        let confidence = confidenceScore(
            source: candidate.source,
            sampleCount: candidate.sampleCount,
            exactSampleCount: candidate.exactSampleCount,
            estimatedSampleCount: candidate.estimatedSampleCount,
            missingSampleCount: candidate.missingSampleCount
        )
        let subtitle = "\(candidate.session.stationDisplayName) • \(NumberFormatting.dateTime(candidate.session.sessionDate))"
        let sharePayload = PersonalRecordSharePayload(
            recordType: type,
            title: type.title,
            headline: metricText,
            detail: subtitle,
            sessionID: candidate.session.id,
            generatedAt: referenceDate,
            source: candidate.source,
            confidenceScore: confidence.score
        )

        return PersonalRecordItem(
            type: type,
            session: candidate.session,
            metricValue: candidate.value,
            metricText: metricText,
            subtitle: subtitle,
            note: note,
            confidence: confidence,
            sharePayload: sharePayload
        )
    }

    private func confidenceScore(
        source: AnalysisDataSourceKind,
        sampleCount: Int,
        exactSampleCount: Int,
        estimatedSampleCount: Int,
        missingSampleCount: Int
    ) -> DataConfidenceScore {
        let baseScore: Int
        switch source {
        case .real:
            baseScore = 76
        case .mixed:
            baseScore = 64
        case .estimated:
            baseScore = 48
        case .unavailable:
            baseScore = 0
        }

        let sampleBoost = min(16, sampleCount * 4)
        let exactBoost = min(10, exactSampleCount * 2)
        let missingPenalty = min(20, missingSampleCount * 2)
        let total = max(0, min(100, baseScore + sampleBoost + exactBoost - missingPenalty))

        return DataConfidenceScore(
            score: total,
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactSampleCount,
            estimatedSampleCount: estimatedSampleCount,
            missingSampleCount: missingSampleCount
        )
    }

    private func note(for source: AnalysisDataSourceKind) -> String? {
        switch source {
        case .real:
            return nil
        case .mixed:
            return "Gercek + tahmini veri"
        case .estimated:
            return "Tahmini veri"
        case .unavailable:
            return "Veri yok"
        }
    }
}
