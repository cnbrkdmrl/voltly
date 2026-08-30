import Foundation

public enum AnalysisDataSourceKind: String, Equatable, Sendable {
    case real
    case mixed
    case estimated
    case unavailable
}

public struct DataConfidenceScore: Equatable, Sendable {
    public let score: Int
    public let source: AnalysisDataSourceKind
    public let sampleCount: Int
    public let exactSampleCount: Int
    public let estimatedSampleCount: Int
    public let missingSampleCount: Int

    public init(
        score: Int,
        source: AnalysisDataSourceKind,
        sampleCount: Int,
        exactSampleCount: Int,
        estimatedSampleCount: Int,
        missingSampleCount: Int
    ) {
        self.score = score
        self.source = source
        self.sampleCount = sampleCount
        self.exactSampleCount = exactSampleCount
        self.estimatedSampleCount = estimatedSampleCount
        self.missingSampleCount = missingSampleCount
    }

    public static let unavailable = DataConfidenceScore(
        score: 0,
        source: .unavailable,
        sampleCount: 0,
        exactSampleCount: 0,
        estimatedSampleCount: 0,
        missingSampleCount: 0
    )
}

public struct InsightMetric<Value: Equatable & Sendable>: Equatable, Sendable {
    public let value: Value?
    public let confidence: DataConfidenceScore

    public init(value: Value?, confidence: DataConfidenceScore) {
        self.value = value
        self.confidence = confidence
    }
}

public struct ChargeInsightUsageRatios: Equatable, Sendable {
    public let homeRatio: InsightMetric<Double>
    public let acRatio: InsightMetric<Double>
    public let dcRatio: InsightMetric<Double>
}

public struct ChargeInsightWindowSummary: Equatable, Sendable {
    public let sessionCount: Int
    public let averageStartSOC: InsightMetric<Double>
    public let averageEndSOC: InsightMetric<Double>
    public let averageEnergyKWh: InsightMetric<Double>
    public let averageDurationMinutes: InsightMetric<Double>
    public let averageTLPerKWh: InsightMetric<Double>
    public let averageTLPer100Km: InsightMetric<Double>
}

public struct ChargeInsightWindowDelta: Equatable, Sendable {
    public let averageStartSOCDelta: InsightMetric<Double>
    public let averageEndSOCDelta: InsightMetric<Double>
    public let averageEnergyKWhDelta: InsightMetric<Double>
    public let averageDurationMinutesDelta: InsightMetric<Double>
    public let averageTLPerKWhDelta: InsightMetric<Double>
    public let averageTLPer100KmDelta: InsightMetric<Double>
}

public struct ChargeActionInsight: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct ChargeInsightReport: Equatable, Sendable {
    public let generatedAt: Date
    public let currencyCode: String
    public let overall: ChargeInsightWindowSummary
    public let lastFiveSessions: ChargeInsightWindowSummary
    public let lastThirtyDays: ChargeInsightWindowSummary
    public let previousThirtyDays: ChargeInsightWindowSummary
    public let previousThirtyDayDelta: ChargeInsightWindowDelta
    public let usageRatios: ChargeInsightUsageRatios
    public let actionInsights: [ChargeActionInsight]
}

public struct ChargeInsightService {
    private enum Constants {
        static let preferredSampleCount = 5.0
        static let estimatedWeight = 0.55
        static let lowSOCThreshold = 15.0
        static let highSOCEndThreshold = 95.0
        static let dcHeavyRatioThreshold = 60.0
        static let costGapOpportunityThreshold = 0.75
        static let rollingDayWindow = 30
        static let recentSessionLimit = 5
    }

    private enum TLPer100ComputationMode {
        case exact
        case estimated
        case unavailable
    }

    private let calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase

    public init(
        calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase = .init()
    ) {
        self.calculateTLPer100KmUseCase = calculateTLPer100KmUseCase
    }

    public func analyze(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) -> ChargeInsightReport {
        let sortedSessions = sessions.sorted { $0.sessionDate < $1.sessionDate }
        let currentThirtyDaySessions = sessionsInPastDays(
            sortedSessions,
            days: Constants.rollingDayWindow,
            endingAt: referenceDate
        )
        let previousThirtyDaySessions = sessionsInPreviousWindow(
            sortedSessions,
            days: Constants.rollingDayWindow,
            referenceDate: referenceDate
        )
        let lastFiveSessions = Array(sortedSessions.suffix(Constants.recentSessionLimit))
        let currencyCode = sortedSessions.first?.currencyCode ?? AppConstants.defaultCurrencyCode

        let overall = makeWindowSummary(vehicle: vehicle, sessions: sortedSessions)
        let lastFive = makeWindowSummary(vehicle: vehicle, sessions: lastFiveSessions)
        let lastThirtyDays = makeWindowSummary(vehicle: vehicle, sessions: currentThirtyDaySessions)
        let previousThirtyDays = makeWindowSummary(vehicle: vehicle, sessions: previousThirtyDaySessions)

        return ChargeInsightReport(
            generatedAt: referenceDate,
            currencyCode: currencyCode,
            overall: overall,
            lastFiveSessions: lastFive,
            lastThirtyDays: lastThirtyDays,
            previousThirtyDays: previousThirtyDays,
            previousThirtyDayDelta: makeWindowDelta(current: lastThirtyDays, previous: previousThirtyDays),
            usageRatios: makeUsageRatios(from: sortedSessions),
            actionInsights: makeActionInsights(
                overall: overall,
                lastThirtyDays: lastThirtyDays,
                previousThirtyDays: previousThirtyDays,
                usageRatios: makeUsageRatios(from: sortedSessions),
                currencyCode: currencyCode
            )
        )
    }

    private func sessionsInPastDays(
        _ sessions: [ChargingSession],
        days: Int,
        endingAt referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let end = referenceDate
        let start = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)

        return sessions.filter { $0.sessionDate >= start && $0.sessionDate <= end }
    }

    private func sessionsInPreviousWindow(
        _ sessions: [ChargingSession],
        days: Int,
        referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let currentWindowStart = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)
        let previousWindowEnd = currentWindowStart.addingTimeInterval(-1)
        let previousWindowStart = calendar.date(
            byAdding: .day,
            value: -days,
            to: currentWindowStart
        ) ?? currentWindowStart

        return sessions.filter { $0.sessionDate >= previousWindowStart && $0.sessionDate <= previousWindowEnd }
    }

    private func makeWindowSummary(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> ChargeInsightWindowSummary {
        ChargeInsightWindowSummary(
            sessionCount: sessions.count,
            averageStartSOC: averageSOCMetric(from: sessions, keyPath: \.socStart),
            averageEndSOC: averageSOCMetric(from: sessions, keyPath: \.socEnd),
            averageEnergyKWh: averageEnergyMetric(from: sessions),
            averageDurationMinutes: averageDurationMetric(from: sessions),
            averageTLPerKWh: averageTLPerKWhMetric(from: sessions),
            averageTLPer100Km: averageTLPer100KmMetric(vehicle: vehicle, sessions: sessions)
        )
    }

    private func makeWindowDelta(
        current: ChargeInsightWindowSummary,
        previous: ChargeInsightWindowSummary
    ) -> ChargeInsightWindowDelta {
        ChargeInsightWindowDelta(
            averageStartSOCDelta: deltaMetric(current.averageStartSOC, previous.averageStartSOC),
            averageEndSOCDelta: deltaMetric(current.averageEndSOC, previous.averageEndSOC),
            averageEnergyKWhDelta: deltaMetric(current.averageEnergyKWh, previous.averageEnergyKWh),
            averageDurationMinutesDelta: deltaMetric(current.averageDurationMinutes, previous.averageDurationMinutes),
            averageTLPerKWhDelta: deltaMetric(current.averageTLPerKWh, previous.averageTLPerKWh),
            averageTLPer100KmDelta: deltaMetric(current.averageTLPer100Km, previous.averageTLPer100Km)
        )
    }

    private func makeUsageRatios(from sessions: [ChargingSession]) -> ChargeInsightUsageRatios {
        let totalCount = sessions.count
        let confidence = makeConfidence(
            exactSamples: totalCount,
            estimatedSamples: 0,
            missingSamples: 0
        )

        func ratio(for method: ChargeMethod) -> InsightMetric<Double> {
            guard totalCount > 0 else {
                return InsightMetric(value: nil, confidence: .unavailable)
            }
            let count = sessions.filter { $0.chargeMethod == method }.count
            return InsightMetric(
                value: (Double(count) / Double(totalCount)) * 100,
                confidence: confidence
            )
        }

        return ChargeInsightUsageRatios(
            homeRatio: ratio(for: .home),
            acRatio: ratio(for: .publicAC),
            dcRatio: ratio(for: .publicDC)
        )
    }

    private func averageSOCMetric(
        from sessions: [ChargingSession],
        keyPath: KeyPath<ChargingSession, Double>
    ) -> InsightMetric<Double> {
        let validSessions = sessions.filter { $0.socEnd > $0.socStart && $0.socEnd > 0 }
        guard !validSessions.isEmpty else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        let value = validSessions.reduce(0.0) { $0 + $1[keyPath: keyPath] } / Double(validSessions.count)
        return InsightMetric(
            value: value,
            confidence: makeConfidence(
                exactSamples: validSessions.count,
                estimatedSamples: 0,
                missingSamples: max(0, sessions.count - validSessions.count)
            )
        )
    }

    private func averageEnergyMetric(from sessions: [ChargingSession]) -> InsightMetric<Double> {
        let validSessions = sessions.compactMap { session -> (Double, Bool)? in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return (energy, session.energyIsEstimated)
        }
        guard !validSessions.isEmpty else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        let average = validSessions.reduce(0.0) { $0 + $1.0 } / Double(validSessions.count)
        let exactSamples = validSessions.filter { !$0.1 }.count
        let estimatedSamples = validSessions.filter(\.1).count

        return InsightMetric(
            value: average,
            confidence: makeConfidence(
                exactSamples: exactSamples,
                estimatedSamples: estimatedSamples,
                missingSamples: max(0, sessions.count - validSessions.count)
            )
        )
    }

    private func averageDurationMetric(from sessions: [ChargingSession]) -> InsightMetric<Double> {
        let durations = sessions.compactMap { session -> Double? in
            guard let minutes = session.durationMin, minutes > 0 else { return nil }
            return Double(minutes)
        }
        guard !durations.isEmpty else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        return InsightMetric(
            value: durations.reduce(0, +) / Double(durations.count),
            confidence: makeConfidence(
                exactSamples: durations.count,
                estimatedSamples: 0,
                missingSamples: max(0, sessions.count - durations.count)
            )
        )
    }

    private func averageTLPerKWhMetric(from sessions: [ChargingSession]) -> InsightMetric<Double> {
        let validSessions = sessions.compactMap { session -> (Double, Bool)? in
            guard let tlPerKWh = session.tlPerKWh else { return nil }
            return (tlPerKWh, session.energyIsEstimated)
        }
        guard !validSessions.isEmpty else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        let average = validSessions.reduce(0.0) { $0 + $1.0 } / Double(validSessions.count)
        let exactSamples = validSessions.filter { !$0.1 }.count
        let estimatedSamples = validSessions.filter(\.1).count

        return InsightMetric(
            value: average,
            confidence: makeConfidence(
                exactSamples: exactSamples,
                estimatedSamples: estimatedSamples,
                missingSamples: max(0, sessions.count - validSessions.count)
            )
        )
    }

    private func averageTLPer100KmMetric(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> InsightMetric<Double> {
        let measured = calculateTLPer100KmUseCase.execute(vehicle: vehicle, sessions: sessions)
        guard let measured else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        let mode = tlPer100ComputationMode(vehicle: vehicle, sessions: sessions)
        let energySamples = sessions.compactMap { session -> Bool? in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return session.energyIsEstimated
        }
        let exactEnergySamples = energySamples.filter { !$0 }.count
        let estimatedEnergySamples = energySamples.filter(\.self).count
        let missingEnergySamples = max(0, sessions.count - energySamples.count)

        let confidence: DataConfidenceScore
        switch mode {
        case .exact:
            confidence = makeConfidence(
                exactSamples: max(2, exactEnergySamples),
                estimatedSamples: estimatedEnergySamples,
                missingSamples: missingEnergySamples,
                preferredSampleCount: Double(Constants.rollingDayWindow)
            )
        case .estimated:
            confidence = makeConfidence(
                exactSamples: 0,
                estimatedSamples: max(1, energySamples.count),
                missingSamples: missingEnergySamples,
                preferredSampleCount: Double(Constants.rollingDayWindow),
                forceSource: .estimated
            )
        case .unavailable:
            confidence = .unavailable
        }

        return InsightMetric(value: measured.value, confidence: confidence)
    }

    private func tlPer100ComputationMode(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> TLPer100ComputationMode {
        let sorted = sessions.sorted { $0.sessionDate < $1.sessionDate }
        let odometerSamples = sorted.compactMap { session -> (Double, Double)? in
            guard let odometer = session.odometerKM,
                  let energy = session.energyKWh,
                  energy > 0 else { return nil }
            return (odometer, energy)
        }

        if odometerSamples.count >= 2 {
            var distanceTotal: Double = 0
            var energyTotal: Double = 0
            for index in 1..<odometerSamples.count {
                let previous = odometerSamples[index - 1]
                let next = odometerSamples[index]
                let distance = next.0 - previous.0
                if distance > 0 {
                    distanceTotal += distance
                    energyTotal += next.1
                }
            }
            if distanceTotal > 0, energyTotal > 0 {
                return .exact
            }
        }

        let totalEnergy = sorted.reduce(0.0) { partial, session in
            partial + max(0, session.energyKWh ?? 0)
        }
        if totalEnergy > 0, (vehicle.factoryConsumptionKWh100km ?? 0) > 0 {
            return .estimated
        }

        return .unavailable
    }

    private func deltaMetric(
        _ current: InsightMetric<Double>,
        _ previous: InsightMetric<Double>
    ) -> InsightMetric<Double> {
        guard let currentValue = current.value, let previousValue = previous.value else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        return InsightMetric(
            value: currentValue - previousValue,
            confidence: combineConfidence(current.confidence, previous.confidence)
        )
    }

    private func combineConfidence(
        _ lhs: DataConfidenceScore,
        _ rhs: DataConfidenceScore
    ) -> DataConfidenceScore {
        guard lhs.source != .unavailable, rhs.source != .unavailable else {
            return .unavailable
        }

        let combinedSource: AnalysisDataSourceKind
        if lhs.source == .real && rhs.source == .real {
            combinedSource = .real
        } else if lhs.source == .estimated && rhs.source == .estimated {
            combinedSource = .estimated
        } else {
            combinedSource = .mixed
        }

        return DataConfidenceScore(
            score: min(lhs.score, rhs.score),
            source: combinedSource,
            sampleCount: min(lhs.sampleCount, rhs.sampleCount),
            exactSampleCount: min(lhs.exactSampleCount, rhs.exactSampleCount),
            estimatedSampleCount: max(lhs.estimatedSampleCount, rhs.estimatedSampleCount),
            missingSampleCount: max(lhs.missingSampleCount, rhs.missingSampleCount)
        )
    }

    private func makeConfidence(
        exactSamples: Int,
        estimatedSamples: Int,
        missingSamples: Int,
        preferredSampleCount: Double = Constants.preferredSampleCount,
        forceSource: AnalysisDataSourceKind? = nil
    ) -> DataConfidenceScore {
        let sampleCount = exactSamples + estimatedSamples
        guard sampleCount > 0 else {
            return .unavailable
        }

        let weighted = Double(exactSamples) + (Double(estimatedSamples) * Constants.estimatedWeight)
        let coverageFactor = min(1.0, Double(sampleCount) / preferredSampleCount)
        let baseScore = Int((weighted / Double(sampleCount) * coverageFactor * 100).rounded())

        let source: AnalysisDataSourceKind
        if let forceSource {
            source = forceSource
        } else if exactSamples > 0, estimatedSamples == 0 {
            source = .real
        } else if exactSamples == 0, estimatedSamples > 0 {
            source = .estimated
        } else {
            source = .mixed
        }

        return DataConfidenceScore(
            score: max(0, min(100, baseScore)),
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactSamples,
            estimatedSampleCount: estimatedSamples,
            missingSampleCount: missingSamples
        )
    }

    private func makeActionInsights(
        overall: ChargeInsightWindowSummary,
        lastThirtyDays: ChargeInsightWindowSummary,
        previousThirtyDays: ChargeInsightWindowSummary,
        usageRatios: ChargeInsightUsageRatios,
        currencyCode: String
    ) -> [ChargeActionInsight] {
        var insights: [ChargeActionInsight] = []

        if let dcRatio = usageRatios.dcRatio.value,
           dcRatio >= Constants.dcHeavyRatioThreshold {
            insights.append(
                ChargeActionInsight(
                    id: "dc-heavy",
                    title: "DC kullanimi yuksek",
                    detail: "Seanslarının %\(Int(dcRatio.rounded())) kadari DC. Uygun gunlerde AC veya ev sarjini artirman maliyeti dengeleyebilir."
                )
            )
        }

        if let startSOC = overall.averageStartSOC.value,
           startSOC < Constants.lowSOCThreshold {
            insights.append(
                ChargeActionInsight(
                    id: "low-start-soc",
                    title: "Cok dusuk seviyede sarj ediyorsun",
                    detail: "Ortalama başlangıç seviyen %\(Int(startSOC.rounded())). Daha erken sarja başlamak günlük kullanım konforunu artırabilir."
                )
            )
        }

        if let endSOC = overall.averageEndSOC.value,
           endSOC >= Constants.highSOCEndThreshold {
            insights.append(
                ChargeActionInsight(
                    id: "high-end-soc",
                    title: "Yuksek bitis yuzdesi dikkat cekiyor",
                    detail: "Ortalama bitiş seviyen %\(Int(endSOC.rounded())). Rutin kullanımda %80-90 bandı daha dengeli olabilir."
                )
            )
        }

        if let currentTLPerKWh = lastThirtyDays.averageTLPerKWh.value,
           let previousTLPerKWh = previousThirtyDays.averageTLPerKWh.value {
            let delta = currentTLPerKWh - previousTLPerKWh
            if delta >= Constants.costGapOpportunityThreshold {
                insights.append(
                    ChargeActionInsight(
                        id: "rising-cost",
                        title: "Son 30 gunde birim maliyet artti",
                        detail: "Son 30 gunde ortalama TL/kWh, onceki 30 güne göre \(NumberFormatting.currency(delta, code: currencyCode)) daha yuksek. Istasyon ve method dagilimini kontrol et."
                    )
                )
            }
        }

        if overall.averageTLPer100Km.confidence.source == .estimated {
            insights.append(
                ChargeActionInsight(
                    id: "estimated-distance",
                    title: "Mesafe hesabi tahmine dayaniyor",
                    detail: "TL/100 km hesabı odometre zinciri yerine fabrika tüketimi fallback'i ile üretiliyor. Daha net analiz için kilometre girişlerini düzenli tut."
                )
            )
        }

        return insights
    }
}
