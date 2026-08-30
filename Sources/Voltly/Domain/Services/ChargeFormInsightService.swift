import Foundation

public struct ChargeFormInsightInput: Equatable {
    public let vehicle: Vehicle
    public let chargeMethod: ChargeMethod
    public let priceTotal: Double?
    public let tariffPricePerKWh: Double?
    public let fallbackTariffPricePerKWh: Double?
    public let energyKWh: Double?
    public let energyIsEstimated: Bool
    public let durationMinutes: Double?
    public let odometerKM: Double?
    public let currencyCode: String

    public init(
        vehicle: Vehicle,
        chargeMethod: ChargeMethod,
        priceTotal: Double?,
        tariffPricePerKWh: Double?,
        fallbackTariffPricePerKWh: Double?,
        energyKWh: Double?,
        energyIsEstimated: Bool,
        durationMinutes: Double?,
        odometerKM: Double?,
        currencyCode: String
    ) {
        self.vehicle = vehicle
        self.chargeMethod = chargeMethod
        self.priceTotal = priceTotal
        self.tariffPricePerKWh = tariffPricePerKWh
        self.fallbackTariffPricePerKWh = fallbackTariffPricePerKWh
        self.energyKWh = energyKWh
        self.energyIsEstimated = energyIsEstimated
        self.durationMinutes = durationMinutes
        self.odometerKM = odometerKM
        self.currencyCode = currencyCode
    }
}

public enum ChargeFormPricePositionKind: String, Equatable {
    case cheaper
    case neutral
    case expensive
    case unavailable
}

public struct ChargeFormPricePositionInsight: Equatable {
    public let kind: ChargeFormPricePositionKind
    public let title: String
    public let detail: String

    public init(kind: ChargeFormPricePositionKind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public struct ChargeFormAlternativeSuggestion: Equatable {
    public let recommendedMethod: ChargeMethod
    public let estimatedSavings: Double
    public let reason: String

    public init(recommendedMethod: ChargeMethod, estimatedSavings: Double, reason: String) {
        self.recommendedMethod = recommendedMethod
        self.estimatedSavings = estimatedSavings
        self.reason = reason
    }
}

public struct ChargeFormLiveInsight: Equatable {
    public let methodDescription: String
    public let tlPerKWh: InsightMetric<Double>
    public let tlPer100Km: InsightMetric<Double>
    public let pricePosition: ChargeFormPricePositionInsight
    public let habitComment: String
    public let alternativeSuggestion: ChargeFormAlternativeSuggestion?

    public init(
        methodDescription: String,
        tlPerKWh: InsightMetric<Double>,
        tlPer100Km: InsightMetric<Double>,
        pricePosition: ChargeFormPricePositionInsight,
        habitComment: String,
        alternativeSuggestion: ChargeFormAlternativeSuggestion?
    ) {
        self.methodDescription = methodDescription
        self.tlPerKWh = tlPerKWh
        self.tlPer100Km = tlPer100Km
        self.pricePosition = pricePosition
        self.habitComment = habitComment
        self.alternativeSuggestion = alternativeSuggestion
    }
}

public struct ChargeFormInsightService {
    private enum Constants {
        static let recentBenchmarkLimit = 8
        static let recentHabitLimit = 12
        static let expensiveThreshold = 0.12
        static let cheaperThreshold = -0.12
        static let strongHabitRatio = 55.0
        static let weakHabitRatio = 25.0
        static let dcToACOpportunityThreshold = 0.10
        static let minimumSuggestedSavings = 10.0
    }

    private let calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase

    public init(
        calculateTLPer100KmUseCase: CalculateTLPer100KmUseCase = .init()
    ) {
        self.calculateTLPer100KmUseCase = calculateTLPer100KmUseCase
    }

    public func makeInsight(
        input: ChargeFormInsightInput,
        history: [ChargingSession]
    ) -> ChargeFormLiveInsight {
        let tlPerKWhMetric = makeTLPerKWhMetric(for: input)
        let tlPer100KmMetric = makeTLPer100KmMetric(
            input: input,
            history: history,
            tlPerKWhMetric: tlPerKWhMetric
        )
        let recentSessions = Array(history.sorted { $0.sessionDate > $1.sessionDate }.prefix(Constants.recentBenchmarkLimit))

        return ChargeFormLiveInsight(
            methodDescription: methodDescription(for: input),
            tlPerKWh: tlPerKWhMetric,
            tlPer100Km: tlPer100KmMetric,
            pricePosition: makePricePositionInsight(
                currentTLPerKWh: tlPerKWhMetric.value,
                benchmarkTLPerKWh: averageTLPerKWh(from: recentSessions)
            ),
            habitComment: makeHabitComment(
                method: input.chargeMethod,
                history: Array(history.sorted { $0.sessionDate > $1.sessionDate }.prefix(Constants.recentHabitLimit))
            ),
            alternativeSuggestion: makeAlternativeSuggestion(
                input: input,
                currentTLPerKWh: tlPerKWhMetric.value,
                history: recentSessions
            )
        )
    }

    private func makeTLPerKWhMetric(for input: ChargeFormInsightInput) -> InsightMetric<Double> {
        if let tariff = validPositiveValue(input.tariffPricePerKWh) {
            return InsightMetric(
                value: tariff,
                confidence: makeConfidence(
                    exactSamples: 1,
                    estimatedSamples: 0,
                    missingSamples: 0
                )
            )
        }

        if let totalPrice = validPositiveValue(input.priceTotal),
           let energyKWh = validPositiveValue(input.energyKWh),
           energyKWh > 0 {
            let tlPerKWh = totalPrice / energyKWh
            return InsightMetric(
                value: tlPerKWh,
                confidence: makeConfidence(
                    exactSamples: input.energyIsEstimated ? 0 : 1,
                    estimatedSamples: input.energyIsEstimated ? 1 : 0,
                    missingSamples: 0
                )
            )
        }

        if input.chargeMethod == .home,
           let fallbackTariff = validPositiveValue(input.fallbackTariffPricePerKWh) {
            return InsightMetric(
                value: fallbackTariff,
                confidence: makeConfidence(
                    exactSamples: 0,
                    estimatedSamples: 1,
                    missingSamples: 0
                )
            )
        }

        return InsightMetric(value: nil, confidence: .unavailable)
    }

    private func makeTLPer100KmMetric(
        input: ChargeFormInsightInput,
        history: [ChargingSession],
        tlPerKWhMetric: InsightMetric<Double>
    ) -> InsightMetric<Double> {
        guard let effectivePrice = resolvedPrice(input: input, tlPerKWhMetric: tlPerKWhMetric),
              let energyKWh = validPositiveValue(input.energyKWh) else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        let predictedSession = ChargingSession(
            vehicleID: input.vehicle.id,
            sessionDate: .now,
            chargeMethod: input.chargeMethod,
            priceTotal: effectivePrice,
            currencyCode: input.currencyCode,
            energyKWh: energyKWh,
            energyIsEstimated: input.energyIsEstimated || tlPerKWhMetric.confidence.source == .estimated,
            socStart: 0,
            socEnd: 0,
            durationMin: validPositiveValue(input.durationMinutes).map(Int.init),
            odometerKM: validPositiveValue(input.odometerKM)
        )

        guard let measuredValue = calculateTLPer100KmUseCase.execute(
            vehicle: input.vehicle,
            sessions: history + [predictedSession]
        ) else {
            return InsightMetric(value: nil, confidence: .unavailable)
        }

        switch measuredValue {
        case .exact(let value):
            return InsightMetric(
                value: value,
                confidence: makeConfidence(exactSamples: 1, estimatedSamples: 0, missingSamples: 0)
            )
        case .estimated(let value):
            return InsightMetric(
                value: value,
                confidence: makeConfidence(exactSamples: 0, estimatedSamples: 1, missingSamples: 0)
            )
        }
    }

    private func makePricePositionInsight(
        currentTLPerKWh: Double?,
        benchmarkTLPerKWh: Double?
    ) -> ChargeFormPricePositionInsight {
        guard let currentTLPerKWh,
              let benchmarkTLPerKWh,
              benchmarkTLPerKWh > 0 else {
            return ChargeFormPricePositionInsight(
                kind: .unavailable,
                title: "Karşılaştırma için yeterli veri yok",
                detail: "Geçmiş seans ortalaması oluştukça burası pahalı/uygun yorumunu gösterecek."
            )
        }

        let deltaRatio = (currentTLPerKWh - benchmarkTLPerKWh) / benchmarkTLPerKWh
        let deltaPercent = abs(Int((deltaRatio * 100).rounded()))

        if deltaRatio >= Constants.expensiveThreshold {
            return ChargeFormPricePositionInsight(
                kind: .expensive,
                title: "Ortalamandan daha pahalı",
                detail: "Bu seçim son ortalamanın yaklaşık %\(deltaPercent) üstünde görünüyor."
            )
        }

        if deltaRatio <= Constants.cheaperThreshold {
            return ChargeFormPricePositionInsight(
                kind: .cheaper,
                title: "Ortalamandan daha uygun",
                detail: "Bu seçim son ortalamanın yaklaşık %\(deltaPercent) altında görünüyor."
            )
        }

        return ChargeFormPricePositionInsight(
            kind: .neutral,
            title: "Ortalama bandında",
            detail: "Bu seçim son seans ortalamanla benzer birim maliyet veriyor."
        )
    }

    private func makeHabitComment(
        method: ChargeMethod,
        history: [ChargingSession]
    ) -> String {
        guard !history.isEmpty else {
            return "Alışkanlık yorumu için yeterli veri yok."
        }

        let methodCount = history.filter { $0.chargeMethod == method }.count
        let ratio = (Double(methodCount) / Double(history.count)) * 100

        if ratio >= Constants.strongHabitRatio {
            return "\(method.titleTR) seçimi son kullanım alışkanlığınla uyumlu görünüyor."
        }

        if ratio <= Constants.weakHabitRatio {
            return "\(method.titleTR) yöntemi son alışkanlıklarında daha seyrek görünüyor."
        }

        return "\(method.titleTR) seçimi kullanım deseninde dengeli bir yerde duruyor."
    }

    private func makeAlternativeSuggestion(
        input: ChargeFormInsightInput,
        currentTLPerKWh: Double?,
        history: [ChargingSession]
    ) -> ChargeFormAlternativeSuggestion? {
        guard input.chargeMethod == .publicDC,
              let currentTLPerKWh,
              let energyKWh = validPositiveValue(input.energyKWh) else {
            return nil
        }

        let acBenchmarkSessions = history.filter { $0.chargeMethod == .publicAC }
        guard let acBenchmark = averageTLPerKWh(from: acBenchmarkSessions),
              currentTLPerKWh > acBenchmark else {
            return nil
        }

        let deltaRatio = (currentTLPerKWh - acBenchmark) / currentTLPerKWh
        let estimatedSavings = (currentTLPerKWh - acBenchmark) * energyKWh

        guard deltaRatio >= Constants.dcToACOpportunityThreshold,
              estimatedSavings >= Constants.minimumSuggestedSavings else {
            return nil
        }

        return ChargeFormAlternativeSuggestion(
            recommendedMethod: .publicAC,
            estimatedSavings: estimatedSavings,
            reason: "AC seçersen yaklaşık \(NumberFormatting.currency(estimatedSavings, code: input.currencyCode)) daha ucuz olabilir. Son AC seansların daha düşük birim maliyet veriyor."
        )
    }

    private func resolvedPrice(
        input: ChargeFormInsightInput,
        tlPerKWhMetric: InsightMetric<Double>
    ) -> Double? {
        if let priceTotal = validPositiveValue(input.priceTotal) {
            return priceTotal
        }

        guard let tlPerKWh = tlPerKWhMetric.value,
              let energyKWh = validPositiveValue(input.energyKWh) else {
            return nil
        }

        return tlPerKWh * energyKWh
    }

    private func averageTLPerKWh(from sessions: [ChargingSession]) -> Double? {
        let values = sessions.compactMap(\.tlPerKWh).filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func methodDescription(for input: ChargeFormInsightInput) -> String {
        switch input.chargeMethod {
        case .home:
            if let fallbackTariff = validPositiveValue(input.fallbackTariffPricePerKWh),
               input.tariffPricePerKWh == nil,
               input.priceTotal == nil {
                return "Ev şarjı genelde en düşük birim maliyeti verir. Varsayılan ev tarifesi \(NumberFormatting.tlPerKWh(fallbackTariff, currencyCode: input.currencyCode)) üzerinden tahmini hesaplama gösteriliyor."
            }
            return "Ev şarjı maliyet odaklıdır. Tarife veya toplam tutar girdikçe hesap daha netleşir."
        case .publicAC:
            return "AC şarj maliyet ve hız arasında daha dengeli bir seçimdir. Uzun park sürelerinde genelde daha avantajlıdır."
        case .publicDC:
            return "DC şarj hız odaklıdır. Özellikle kısa duraklarda işe yarar ama birim maliyeti çoğu senaryoda daha yüksek olur."
        }
    }

    private func makeConfidence(
        exactSamples: Int,
        estimatedSamples: Int,
        missingSamples: Int
    ) -> DataConfidenceScore {
        let sampleCount = exactSamples + estimatedSamples + missingSamples
        guard sampleCount > 0 else { return .unavailable }

        let weightedScore = (exactSamples * 100) + Int(Double(estimatedSamples) * 55.0)
        let normalizedScore = max(0, min(100, weightedScore / sampleCount))

        let source: AnalysisDataSourceKind
        switch (exactSamples > 0, estimatedSamples > 0) {
        case (true, true):
            source = .mixed
        case (true, false):
            source = .real
        case (false, true):
            source = .estimated
        default:
            source = .unavailable
        }

        return DataConfidenceScore(
            score: normalizedScore,
            source: source,
            sampleCount: sampleCount,
            exactSampleCount: exactSamples,
            estimatedSampleCount: estimatedSamples,
            missingSampleCount: missingSamples
        )
    }

    private func validPositiveValue(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
