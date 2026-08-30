import Foundation

public enum ChargeSessionScoreLabel: String, Equatable, Sendable {
    case veryGood
    case good
    case average
    case expensive
    case inefficient

    public var title: String {
        ChargeSessionScoringText.labelTitle(self)
    }
}

public struct ChargeSessionScoreComponent: Equatable, Sendable {
    public let title: String
    public let score: Double
    public let confidence: DataConfidenceScore

    public init(title: String, score: Double, confidence: DataConfidenceScore) {
        self.title = title
        self.score = score
        self.confidence = confidence
    }
}

public struct ChargeSessionScoreInsight: Identifiable, Equatable, Sendable {
    public let id: String
    public let message: String

    public init(id: String, message: String) {
        self.id = id
        self.message = message
    }
}

public struct ChargeSessionScoreReport: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let overallScore: Double
    public let label: ChargeSessionScoreLabel
    public let confidence: DataConfidenceScore
    public let priceScore: ChargeSessionScoreComponent
    public let efficiencyScore: ChargeSessionScoreComponent
    public let chargeRangeScore: ChargeSessionScoreComponent
    public let primaryComment: String
    public let insights: [ChargeSessionScoreInsight]

    public init(
        sessionID: UUID,
        overallScore: Double,
        label: ChargeSessionScoreLabel,
        confidence: DataConfidenceScore,
        priceScore: ChargeSessionScoreComponent,
        efficiencyScore: ChargeSessionScoreComponent,
        chargeRangeScore: ChargeSessionScoreComponent,
        primaryComment: String,
        insights: [ChargeSessionScoreInsight]
    ) {
        id = sessionID
        self.sessionID = sessionID
        self.overallScore = overallScore
        self.label = label
        self.confidence = confidence
        self.priceScore = priceScore
        self.efficiencyScore = efficiencyScore
        self.chargeRangeScore = chargeRangeScore
        self.primaryComment = primaryComment
        self.insights = insights
    }
}

public struct ChargeSessionScoringService {
    private enum Constants {
        static let minScore = 0.0
        static let maxScore = 10.0
        static let neutralScore = 6.5

        static let priceWeight = 0.40
        static let efficiencyWeight = 0.35
        static let rangeWeight = 0.25

        static let recentBenchmarkSessionCount = 5
        static let significantDeltaThreshold = 0.08
        static let dominantDCRatioThreshold = 55.0

        static let healthySOCStartRange = 10.0...30.0
        static let healthySOCEndRange = 75.0...90.0
        static let idealChargeWindowRange = 35.0...70.0
        static let dcHighEndPenaltyThreshold = 90.0
        static let linearPenaltyPerPercent = 0.22
        static let wideWindowPenalty = 1.5
        static let dcHighEndPenalty = 2.0

        static let preferredSampleCount = 5.0
    }

    private let calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase

    public init(
        calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase = .init()
    ) {
        self.calculateTLPer100KmUseCase = calculateTLPer100KmUseCase
    }

    public func score(
        session: ChargingSession,
        vehicle: Vehicle,
        history: [ChargingSession]
    ) -> ChargeSessionScoreReport {
        let orderedHistory = history
            .filter { $0.vehicleID == session.vehicleID }
            .sorted { $0.sessionDate > $1.sessionDate }
        let comparableHistory = orderedHistory.filter { $0.id != session.id }
        let priceComponent = makePriceScore(session: session, history: comparableHistory)
        let efficiencyComponent = makeEfficiencyScore(
            session: session,
            vehicle: vehicle,
            history: comparableHistory
        )
        let chargeRangeComponent = makeChargeRangeScore(session: session)
        let overallScore = weightedAverage(
            price: priceComponent.score,
            efficiency: efficiencyComponent.score,
            chargeRange: chargeRangeComponent.score
        )
        let label = resolveLabel(
            overallScore: overallScore,
            priceScore: priceComponent.score,
            efficiencyScore: efficiencyComponent.score
        )
        let confidence = mergedConfidence(
            [priceComponent.confidence, efficiencyComponent.confidence, chargeRangeComponent.confidence]
        )
        let insights = buildInsights(
            session: session,
            vehicle: vehicle,
            history: orderedHistory,
            price: priceComponent,
            efficiency: efficiencyComponent,
            chargeRange: chargeRangeComponent
        )

        return ChargeSessionScoreReport(
            sessionID: session.id,
            overallScore: overallScore,
            label: label,
            confidence: confidence,
            priceScore: priceComponent,
            efficiencyScore: efficiencyComponent,
            chargeRangeScore: chargeRangeComponent,
            primaryComment: insights.first?.message ?? ChargeSessionScoringText.missingDataComment,
            insights: insights
        )
    }

    public func scoreReports(
        sessions: [ChargingSession],
        vehiclesByID: [UUID: Vehicle]
    ) -> [UUID: ChargeSessionScoreReport] {
        let groupedSessions = Dictionary(grouping: sessions, by: \.vehicleID)
        var reports: [UUID: ChargeSessionScoreReport] = [:]

        for (vehicleID, vehicleSessions) in groupedSessions {
            guard let vehicle = vehiclesByID[vehicleID] else { continue }
            for session in vehicleSessions {
                reports[session.id] = score(
                    session: session,
                    vehicle: vehicle,
                    history: vehicleSessions
                )
            }
        }

        return reports
    }

    private func makePriceScore(
        session: ChargingSession,
        history: [ChargingSession]
    ) -> ChargeSessionScoreComponent {
        guard let sessionTLPerKWh = session.tlPerKWh else {
            return ChargeSessionScoreComponent(
                title: ChargeSessionScoringText.priceTitle,
                score: Constants.neutralScore,
                confidence: .unavailable
            )
        }

        let benchmarkSessions = benchmarkSessions(for: session, in: history) { $0.tlPerKWh }
        let benchmarkValues = benchmarkSessions.compactMap(\.tlPerKWh)
        guard let benchmark = average(of: benchmarkValues) else {
            return ChargeSessionScoreComponent(
                title: ChargeSessionScoringText.priceTitle,
                score: Constants.neutralScore,
                confidence: confidence(
                    source: .estimated,
                    sampleCount: 1,
                    exactSampleCount: 1,
                    estimatedSampleCount: 0,
                    missingSampleCount: max(history.count - 1, 0)
                )
            )
        }

        let deltaRatio = (sessionTLPerKWh - benchmark) / benchmark
        let score = clamped(Constants.neutralScore - (deltaRatio * 15.0))
        return ChargeSessionScoreComponent(
            title: ChargeSessionScoringText.priceTitle,
            score: score,
            confidence: confidence(
                source: .real,
                sampleCount: benchmarkValues.count + 1,
                exactSampleCount: benchmarkValues.count + 1,
                estimatedSampleCount: 0,
                missingSampleCount: max(history.count - benchmarkValues.count, 0)
            )
        )
    }

    private func makeEfficiencyScore(
        session: ChargingSession,
        vehicle: Vehicle,
        history: [ChargingSession]
    ) -> ChargeSessionScoreComponent {
        guard let currentSessionTLPer100Km = sessionTLPer100KmValue(
            session: session,
            vehicle: vehicle,
            history: history
        ) else {
            return ChargeSessionScoreComponent(
                title: ChargeSessionScoringText.efficiencyTitle,
                score: Constants.neutralScore,
                confidence: .unavailable
            )
        }

        let benchmarkSessions = benchmarkSessions(for: session, in: history) {
            sessionTLPer100KmValue(session: $0, vehicle: vehicle, history: history)?.value
        }
        let benchmarkValues = benchmarkSessions.compactMap {
            sessionTLPer100KmValue(session: $0, vehicle: vehicle, history: history)
        }

        guard let benchmark = average(of: benchmarkValues.map(\.value)) else {
            let source: AnalysisDataSourceKind = currentSessionTLPer100Km.isEstimated ? .estimated : .real
            return ChargeSessionScoreComponent(
                title: ChargeSessionScoringText.efficiencyTitle,
                score: Constants.neutralScore,
                confidence: confidence(
                    source: source,
                    sampleCount: 1,
                    exactSampleCount: currentSessionTLPer100Km.isEstimated ? 0 : 1,
                    estimatedSampleCount: currentSessionTLPer100Km.isEstimated ? 1 : 0,
                    missingSampleCount: max(history.count - 1, 0)
                )
            )
        }

        let deltaRatio = (currentSessionTLPer100Km.value - benchmark) / benchmark
        let score = clamped(Constants.neutralScore - (deltaRatio * 14.0))
        let exactCount = benchmarkValues.filter { !$0.isEstimated }.count + (currentSessionTLPer100Km.isEstimated ? 0 : 1)
        let estimatedCount = benchmarkValues.filter(\.isEstimated).count + (currentSessionTLPer100Km.isEstimated ? 1 : 0)
        let source: AnalysisDataSourceKind
        switch (exactCount > 0, estimatedCount > 0) {
        case (true, false): source = .real
        case (true, true): source = .mixed
        case (false, true): source = .estimated
        default: source = .unavailable
        }

        return ChargeSessionScoreComponent(
            title: ChargeSessionScoringText.efficiencyTitle,
            score: score,
            confidence: confidence(
                source: source,
                sampleCount: benchmarkValues.count + 1,
                exactSampleCount: exactCount,
                estimatedSampleCount: estimatedCount,
                missingSampleCount: max(history.count - benchmarkValues.count, 0)
            )
        )
    }

    private func makeChargeRangeScore(session: ChargingSession) -> ChargeSessionScoreComponent {
        let startPenalty = distanceFromHealthyRange(
            value: session.socStart,
            range: Constants.healthySOCStartRange
        ) * Constants.linearPenaltyPerPercent
        let endPenalty = distanceFromHealthyRange(
            value: session.socEnd,
            range: Constants.healthySOCEndRange
        ) * Constants.linearPenaltyPerPercent
        let sessionWindow = max(0, session.socEnd - session.socStart)
        let windowPenalty = Constants.idealChargeWindowRange.contains(sessionWindow) ? 0 : Constants.wideWindowPenalty
        let dcPenalty = session.chargeMethod == .publicDC && session.socEnd > Constants.dcHighEndPenaltyThreshold
            ? Constants.dcHighEndPenalty
            : 0

        let score = clamped(10 - startPenalty - endPenalty - windowPenalty - dcPenalty)

        return ChargeSessionScoreComponent(
            title: ChargeSessionScoringText.rangeTitle,
            score: score,
            confidence: confidence(
                source: .real,
                sampleCount: 1,
                exactSampleCount: 1,
                estimatedSampleCount: 0,
                missingSampleCount: 0
            )
        )
    }

    private func buildInsights(
        session: ChargingSession,
        vehicle: Vehicle,
        history: [ChargingSession],
        price: ChargeSessionScoreComponent,
        efficiency: ChargeSessionScoreComponent,
        chargeRange: ChargeSessionScoreComponent
    ) -> [ChargeSessionScoreInsight] {
        var insights: [ChargeSessionScoreInsight] = []

        if let sessionTLPerKWh = session.tlPerKWh,
           let benchmark = average(of: benchmarkSessions(for: session, in: history.filter { $0.id != session.id }) { $0.tlPerKWh }.compactMap(\.tlPerKWh)),
           benchmark > 0 {
            let deltaRatio = (sessionTLPerKWh - benchmark) / benchmark
            if abs(deltaRatio) >= Constants.significantDeltaThreshold {
                let message = deltaRatio > 0
                    ? ChargeSessionScoringText.moreExpensiveComment(deltaPercent: deltaRatio * 100)
                    : ChargeSessionScoringText.cheaperComment(deltaPercent: abs(deltaRatio) * 100)
                insights.append(.init(id: "price-delta", message: message))
            }
        }

        if chargeRange.score >= 8.0 {
            insights.append(.init(id: "healthy-range", message: ChargeSessionScoringText.healthyRangeComment))
        } else if session.chargeMethod == .publicDC, session.socEnd > Constants.dcHighEndPenaltyThreshold {
            insights.append(.init(id: "dc-high-end", message: ChargeSessionScoringText.highEndDCComment))
        } else if session.socStart < Constants.healthySOCStartRange.lowerBound {
            insights.append(.init(id: "low-start", message: ChargeSessionScoringText.lowStartComment))
        } else {
            insights.append(.init(id: "wide-range", message: ChargeSessionScoringText.wideRangeComment))
        }

        if let currentSessionTLPer100Km = sessionTLPer100KmValue(
            session: session,
            vehicle: vehicle,
            history: history.filter { $0.id != session.id }
        ),
           let benchmark = average(
                of: benchmarkSessions(for: session, in: history.filter { $0.id != session.id }) {
                    sessionTLPer100KmValue(session: $0, vehicle: vehicle, history: history.filter { $0.id != session.id })?.value
                }.compactMap {
                    sessionTLPer100KmValue(session: $0, vehicle: vehicle, history: history.filter { $0.id != session.id })?.value
                }
           ),
           benchmark > 0 {
            let deltaRatio = (currentSessionTLPer100Km.value - benchmark) / benchmark
            if abs(deltaRatio) >= Constants.significantDeltaThreshold {
                let message = deltaRatio > 0
                    ? ChargeSessionScoringText.efficiencyWorseComment(deltaPercent: deltaRatio * 100)
                    : ChargeSessionScoringText.efficiencyBetterComment(deltaPercent: abs(deltaRatio) * 100)
                insights.append(.init(id: "efficiency-delta", message: message))
            }
        } else if efficiency.confidence.source == .estimated {
            insights.append(.init(id: "estimated-efficiency", message: ChargeSessionScoringText.estimatedEfficiencyComment))
        }

        let dcRatio = makeDCRatio(from: history)
        if session.chargeMethod == .publicDC, dcRatio >= Constants.dominantDCRatioThreshold {
            insights.append(.init(id: "dc-ratio", message: ChargeSessionScoringText.dcUsageComment(dcRatio: dcRatio)))
        }

        if insights.isEmpty {
            insights.append(.init(id: "missing-data", message: ChargeSessionScoringText.missingDataComment))
        }

        return Array(insights.prefix(3))
    }

    private func sessionTLPer100KmValue(
        session: ChargingSession,
        vehicle: Vehicle,
        history: [ChargingSession]
    ) -> MeasuredValue<Double>? {
        if let exact = odometerDerivedTLPer100Km(session: session, history: history) {
            return exact
        }

        guard let tlPerKWh = session.tlPerKWh,
              let factoryConsumption = vehicle.factoryConsumptionKWh100km,
              factoryConsumption > 0 else {
            return nil
        }

        return .estimated(tlPerKWh * factoryConsumption)
    }

    private func odometerDerivedTLPer100Km(
        session: ChargingSession,
        history: [ChargingSession]
    ) -> MeasuredValue<Double>? {
        guard let odometer = session.odometerKM,
              let energy = session.energyKWh,
              energy > 0 else {
            return nil
        }

        let previousSession = history
            .filter { $0.id != session.id && $0.sessionDate < session.sessionDate }
            .compactMap { candidate -> (session: ChargingSession, odometer: Double)? in
                guard let candidateOdometer = candidate.odometerKM else { return nil }
                return (candidate, candidateOdometer)
            }
            .sorted { $0.session.sessionDate > $1.session.sessionDate }
            .first

        guard let previousSession else { return nil }
        let distance = odometer - previousSession.odometer
        guard distance > 0 else { return nil }

        let tlPer100Km = (session.priceTotal / distance) * 100
        return session.energyIsEstimated ? .estimated(tlPer100Km) : .exact(tlPer100Km)
    }

    private func benchmarkSessions(
        for session: ChargingSession,
        in history: [ChargingSession],
        metric: (ChargingSession) -> Double?
    ) -> [ChargingSession] {
        let methodMatched = history.filter {
            $0.chargeMethod == session.chargeMethod && metric($0) != nil
        }
        if !methodMatched.isEmpty {
            return Array(methodMatched.prefix(Constants.recentBenchmarkSessionCount))
        }

        let allMatched = history.filter { metric($0) != nil }
        return Array(allMatched.prefix(Constants.recentBenchmarkSessionCount))
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func weightedAverage(price: Double, efficiency: Double, chargeRange: Double) -> Double {
        clamped(
            (price * Constants.priceWeight) +
            (efficiency * Constants.efficiencyWeight) +
            (chargeRange * Constants.rangeWeight)
        )
    }

    private func resolveLabel(
        overallScore: Double,
        priceScore: Double,
        efficiencyScore: Double
    ) -> ChargeSessionScoreLabel {
        if overallScore >= 8.5 {
            return .veryGood
        }
        if overallScore >= 7.0 {
            return .good
        }
        if priceScore <= 3.5 {
            return .expensive
        }
        if efficiencyScore <= 3.5 {
            return .inefficient
        }
        return .average
    }

    private func mergedConfidence(_ scores: [DataConfidenceScore]) -> DataConfidenceScore {
        guard !scores.isEmpty else { return .unavailable }
        let sampleCount = scores.reduce(0) { $0 + $1.sampleCount }
        let exactCount = scores.reduce(0) { $0 + $1.exactSampleCount }
        let estimatedCount = scores.reduce(0) { $0 + $1.estimatedSampleCount }
        let missingCount = scores.reduce(0) { $0 + $1.missingSampleCount }
        let averageScore = Int((Double(scores.reduce(0) { $0 + $1.score }) / Double(scores.count)).rounded())
        let source: AnalysisDataSourceKind
        switch (exactCount > 0, estimatedCount > 0) {
        case (true, false): source = .real
        case (true, true): source = .mixed
        case (false, true): source = .estimated
        default: source = .unavailable
        }
        return confidence(
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactCount,
            estimatedSampleCount: estimatedCount,
            missingSampleCount: missingCount,
            preferredScore: averageScore
        )
    }

    private func confidence(
        source: AnalysisDataSourceKind,
        sampleCount: Int,
        exactSampleCount: Int,
        estimatedSampleCount: Int,
        missingSampleCount: Int,
        preferredScore: Int? = nil
    ) -> DataConfidenceScore {
        let coverage = min(Double(sampleCount) / Constants.preferredSampleCount, 1)
        let baseScore: Double
        switch source {
        case .real: baseScore = 100
        case .mixed: baseScore = 76
        case .estimated: baseScore = 58
        case .unavailable: baseScore = 0
        }

        let computedScore = Int((baseScore * coverage).rounded())
        return DataConfidenceScore(
            score: preferredScore ?? computedScore,
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactSampleCount,
            estimatedSampleCount: estimatedSampleCount,
            missingSampleCount: missingSampleCount
        )
    }

    private func distanceFromHealthyRange(value: Double, range: ClosedRange<Double>) -> Double {
        if range.contains(value) { return 0 }
        if value < range.lowerBound { return range.lowerBound - value }
        return value - range.upperBound
    }

    private func makeDCRatio(from history: [ChargingSession]) -> Double {
        guard !history.isEmpty else { return 0 }
        let dcCount = history.filter { $0.chargeMethod == .publicDC }.count
        return (Double(dcCount) / Double(history.count)) * 100
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, Constants.minScore), Constants.maxScore)
    }
}
