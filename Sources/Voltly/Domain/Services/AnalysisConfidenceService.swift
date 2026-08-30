import Foundation

public enum AnalysisConfidenceLevel: String, Equatable, Sendable {
    case high
    case medium
    case low

    public var titleTR: String {
        switch self {
        case .high:
            return "Yüksek güven"
        case .medium:
            return "Orta güven"
        case .low:
            return "Düşük güven"
        }
    }
}

public enum AnalysisConfidenceContext: String, Equatable, Sendable {
    case chargeHabit
    case vehicleEfficiency
    case savings
}

public struct AnalysisConfidenceReport: Equatable, Sendable {
    public let level: AnalysisConfidenceLevel
    public let score: Int
    public let realDataPercent: Int
    public let source: AnalysisDataSourceKind
    public let primaryText: String
    public let secondaryText: String?
    public let sampleCount: Int
    public let missingKMRatio: Double
    public let fallbackRatio: Double
    public let inconsistentRatio: Double

    public init(
        level: AnalysisConfidenceLevel,
        score: Int,
        realDataPercent: Int,
        source: AnalysisDataSourceKind,
        primaryText: String,
        secondaryText: String?,
        sampleCount: Int,
        missingKMRatio: Double,
        fallbackRatio: Double,
        inconsistentRatio: Double
    ) {
        self.level = level
        self.score = score
        self.realDataPercent = realDataPercent
        self.source = source
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.sampleCount = sampleCount
        self.missingKMRatio = missingKMRatio
        self.fallbackRatio = fallbackRatio
        self.inconsistentRatio = inconsistentRatio
    }
}

public struct AnalysisConfidenceService {
    private enum Constants {
        static let minimumSessionCount = 3.0
        static let preferredSessionCount = 12.0

        static let dataVolumeWeight = 0.35
        static let missingKMWeight = 0.20
        static let fallbackWeight = 0.25
        static let inconsistencyWeight = 0.20

        static let highConfidenceThreshold = 76
        static let mediumConfidenceThreshold = 55

        static let maxDistancePerSessionKM = 2_500.0
        static let maxDistancePerDayKM = 1_200.0
    }

    public init() {}

    public func evaluate(
        context: AnalysisConfidenceContext,
        sessions: [ChargingSession],
        primaryMetricConfidence: DataConfidenceScore?
    ) -> AnalysisConfidenceReport? {
        guard !sessions.isEmpty else { return nil }

        let sampleCount = max(
            sessions.count,
            primaryMetricConfidence?.sampleCount ?? 0
        )
        guard Double(sampleCount) >= Constants.minimumSessionCount else { return nil }

        let missingKMRatio = missingKMRatio(from: sessions)
        let fallbackRatio = fallbackRatio(
            sessions: sessions,
            primaryMetricConfidence: primaryMetricConfidence
        )
        let inconsistentRatio = inconsistentRatio(from: sessions)
        let volumeFactor = min(1.0, Double(sampleCount) / Constants.preferredSessionCount)

        let score = calculateScore(
            volumeFactor: volumeFactor,
            missingKMRatio: missingKMRatio,
            fallbackRatio: fallbackRatio,
            inconsistentRatio: inconsistentRatio
        )
        let level = level(for: score)
        let source = resolveSource(
            primaryMetricConfidence: primaryMetricConfidence,
            fallbackRatio: fallbackRatio
        )
        let realDataPercent = realDataPercent(
            sessions: sessions,
            primaryMetricConfidence: primaryMetricConfidence,
            fallbackRatio: fallbackRatio
        )

        let primaryText = "\(contextTitle(context)): %\(realDataPercent) gerçek veriye dayanıyor."
        let secondaryText = secondaryText(
            context: context,
            level: level,
            missingKMRatio: missingKMRatio,
            fallbackRatio: fallbackRatio,
            inconsistentRatio: inconsistentRatio
        )

        return AnalysisConfidenceReport(
            level: level,
            score: score,
            realDataPercent: realDataPercent,
            source: source,
            primaryText: primaryText,
            secondaryText: secondaryText,
            sampleCount: sampleCount,
            missingKMRatio: missingKMRatio,
            fallbackRatio: fallbackRatio,
            inconsistentRatio: inconsistentRatio
        )
    }

    private func calculateScore(
        volumeFactor: Double,
        missingKMRatio: Double,
        fallbackRatio: Double,
        inconsistentRatio: Double
    ) -> Int {
        let value =
            (volumeFactor * Constants.dataVolumeWeight) +
            ((1 - missingKMRatio) * Constants.missingKMWeight) +
            ((1 - fallbackRatio) * Constants.fallbackWeight) +
            ((1 - inconsistentRatio) * Constants.inconsistencyWeight)

        return max(0, min(100, Int((value * 100).rounded())))
    }

    private func level(for score: Int) -> AnalysisConfidenceLevel {
        if score >= Constants.highConfidenceThreshold {
            return .high
        }
        if score >= Constants.mediumConfidenceThreshold {
            return .medium
        }
        return .low
    }

    private func resolveSource(
        primaryMetricConfidence: DataConfidenceScore?,
        fallbackRatio: Double
    ) -> AnalysisDataSourceKind {
        if let primaryMetricConfidence {
            return primaryMetricConfidence.source
        }
        if fallbackRatio >= 0.8 {
            return .estimated
        }
        if fallbackRatio > 0 {
            return .mixed
        }
        return .real
    }

    private func realDataPercent(
        sessions: [ChargingSession],
        primaryMetricConfidence: DataConfidenceScore?,
        fallbackRatio: Double
    ) -> Int {
        if let primaryMetricConfidence, primaryMetricConfidence.sampleCount > 0 {
            let ratio = Double(primaryMetricConfidence.exactSampleCount) / Double(primaryMetricConfidence.sampleCount)
            return max(0, min(100, Int((ratio * 100).rounded())))
        }

        let observedEnergySamples = sessions.compactMap { session -> Bool? in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return !session.energyIsEstimated
        }
        if !observedEnergySamples.isEmpty {
            let realCount = observedEnergySamples.filter { $0 }.count
            let ratio = Double(realCount) / Double(observedEnergySamples.count)
            return max(0, min(100, Int((ratio * 100).rounded())))
        }

        return max(0, min(100, Int(((1 - fallbackRatio) * 100).rounded())))
    }

    private func missingKMRatio(from sessions: [ChargingSession]) -> Double {
        guard !sessions.isEmpty else { return 1 }
        let missing = sessions.filter { session in
            session.odometerKM == nil || (session.odometerKM ?? 0) <= 0
        }.count
        return clampRatio(Double(missing) / Double(sessions.count))
    }

    private func fallbackRatio(
        sessions: [ChargingSession],
        primaryMetricConfidence: DataConfidenceScore?
    ) -> Double {
        if let primaryMetricConfidence,
           primaryMetricConfidence.sampleCount > 0 {
            let ratio = Double(primaryMetricConfidence.estimatedSampleCount) / Double(primaryMetricConfidence.sampleCount)
            return clampRatio(ratio)
        }

        let energySamples = sessions.compactMap { session -> Bool? in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return session.energyIsEstimated
        }
        guard !energySamples.isEmpty else { return 1 }

        let estimatedCount = energySamples.filter { $0 }.count
        return clampRatio(Double(estimatedCount) / Double(energySamples.count))
    }

    private func inconsistentRatio(from sessions: [ChargingSession]) -> Double {
        guard !sessions.isEmpty else { return 1 }

        let invalidFieldCount = sessions.filter(isFieldInconsistent(_:)).count
        let invalidTransitionCount = invalidOdometerTransitionCount(from: sessions)
        let combined = Double(invalidFieldCount + invalidTransitionCount) / Double(sessions.count)
        return clampRatio(combined)
    }

    private func isFieldInconsistent(_ session: ChargingSession) -> Bool {
        if session.priceTotal < 0 {
            return true
        }
        if !(0...100).contains(session.socStart) || !(0...100).contains(session.socEnd) || session.socEnd <= session.socStart {
            return true
        }
        if let energy = session.energyKWh, energy <= 0 {
            return true
        }
        if let duration = session.durationMin, duration <= 0 {
            return true
        }
        return false
    }

    private func invalidOdometerTransitionCount(from sessions: [ChargingSession]) -> Int {
        let odometerChain = sessions
            .compactMap { session -> (Date, Double)? in
                guard let odometer = session.odometerKM else { return nil }
                return (session.sessionDate, odometer)
            }
            .sorted { $0.0 < $1.0 }

        guard odometerChain.count >= 2 else { return 0 }

        var invalid = 0
        for index in 1..<odometerChain.count {
            let previous = odometerChain[index - 1]
            let current = odometerChain[index]
            if !isPlausibleDistance(
                current.1 - previous.1,
                from: previous.0,
                to: current.0
            ) {
                invalid += 1
            }
        }
        return invalid
    }

    private func isPlausibleDistance(
        _ distance: Double,
        from startDate: Date,
        to endDate: Date
    ) -> Bool {
        guard distance > 0, distance <= Constants.maxDistancePerSessionKM else {
            return false
        }

        let interval = max(endDate.timeIntervalSince(startDate), 3600)
        let intervalDays = interval / 86_400
        let maxPlausibleDistance = max(
            Constants.maxDistancePerDayKM,
            intervalDays * Constants.maxDistancePerDayKM
        )
        return distance <= maxPlausibleDistance
    }

    private func contextTitle(_ context: AnalysisConfidenceContext) -> String {
        switch context {
        case .chargeHabit:
            return "Alışkanlık analizi"
        case .vehicleEfficiency:
            return "Verim analizi"
        case .savings:
            return "Tasarruf analizi"
        }
    }

    private func secondaryText(
        context: AnalysisConfidenceContext,
        level: AnalysisConfidenceLevel,
        missingKMRatio: Double,
        fallbackRatio: Double,
        inconsistentRatio: Double
    ) -> String? {
        if fallbackRatio >= 0.25 {
            return "Bazı kayıtlar tahmini hesaplandığı için sonuç yaklaşık görünebilir."
        }
        if missingKMRatio >= 0.35 {
            return context == .vehicleEfficiency
                ? "Km verisi eksik kaldığında verim hesabı daha temkinli yorumlanır."
                : "Km verisi eksik olduğu için analiz güveni bir miktar düşebilir."
        }
        if inconsistentRatio >= 0.20 {
            return "Tutarsız görünen bazı kayıtlar otomatik olarak daha düşük ağırlıkla değerlendirildi."
        }
        if level == .low {
            return "Yeni kayıtlar geldikçe analiz güveni hızlıca yükselecek."
        }
        return nil
    }

    private func clampRatio(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
