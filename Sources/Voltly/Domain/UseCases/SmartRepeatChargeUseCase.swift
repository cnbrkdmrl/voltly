import Foundation

public struct SmartRepeatChargePrefill: Equatable {
    public let chargeMethod: ChargeMethod
    public let stationBrand: String?
    public let locationName: String?
    public let tariffPricePerKWh: Double?
    public let referencePriceTotal: Double?
}

public struct SmartRepeatChargeRecommendation: Equatable {
    public let recommendedMethod: ChargeMethod
    public let reason: String
    public let suggestedTariffPricePerKWh: Double?
}

public struct SmartRepeatChargePlan: Equatable {
    public let templateSession: ChargingSession
    public let prefill: SmartRepeatChargePrefill
    public let title: String
    public let subtitle: String
    public let latestSessionInsight: String?
    public let scoreReport: ChargeSessionScoreReport?
    public let recommendation: SmartRepeatChargeRecommendation?
}

public struct SmartRepeatChargeUseCase {
    private enum Constants {
        static let recentBenchmarkLimit = 8
        static let recommendationGapThreshold = 0.12
        static let minimumMethodSampleCount = 2
    }

    private struct MethodBenchmark {
        let method: ChargeMethod
        let averageTLPerKWh: Double
        let sampleCount: Int
        let isEstimated: Bool
    }

    private let scoringService: ChargeSessionScoringService

    public init(scoringService: ChargeSessionScoringService = .init()) {
        self.scoringService = scoringService
    }

    public func execute(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        electricityPricePerKWh: Double?
    ) -> SmartRepeatChargePlan? {
        let orderedSessions = sessions.sorted { $0.sessionDate > $1.sessionDate }
        guard let latestSession = orderedSessions.first else { return nil }

        let prefill = SmartRepeatChargePrefill(
            chargeMethod: latestSession.chargeMethod,
            stationBrand: latestSession.stationBrand,
            locationName: latestSession.locationName,
            tariffPricePerKWh: latestSession.tlPerKWh,
            referencePriceTotal: latestSession.priceTotal
        )

        let scoreReport = scoringService.score(
            session: latestSession,
            vehicle: vehicle,
            history: orderedSessions
        )

        return SmartRepeatChargePlan(
            templateSession: latestSession,
            prefill: prefill,
            title: "Akıllı hızlı giriş",
            subtitle: "Son seansını baz alır, alanları doldurur ve daha iyi seçenek varsa gösterir.",
            latestSessionInsight: scoreReport.primaryComment,
            scoreReport: scoreReport,
            recommendation: makeRecommendation(
                latestSession: latestSession,
                sessions: orderedSessions,
                electricityPricePerKWh: electricityPricePerKWh
            )
        )
    }

    private func makeRecommendation(
        latestSession: ChargingSession,
        sessions: [ChargingSession],
        electricityPricePerKWh: Double?
    ) -> SmartRepeatChargeRecommendation? {
        let benchmarks = methodBenchmarks(
            sessions: sessions,
            electricityPricePerKWh: electricityPricePerKWh
        )
        guard let currentBenchmark = benchmarks[latestSession.chargeMethod] else {
            return nil
        }

        let alternatives = benchmarks.values
            .filter { $0.method != latestSession.chargeMethod }
            .filter { $0.sampleCount >= Constants.minimumMethodSampleCount || $0.method == .home }
            .sorted { $0.averageTLPerKWh < $1.averageTLPerKWh }

        guard let bestAlternative = alternatives.first else { return nil }

        let gapRatio = (currentBenchmark.averageTLPerKWh - bestAlternative.averageTLPerKWh) / currentBenchmark.averageTLPerKWh
        guard gapRatio >= Constants.recommendationGapThreshold else { return nil }

        return SmartRepeatChargeRecommendation(
            recommendedMethod: bestAlternative.method,
            reason: recommendationReason(
                currentMethod: latestSession.chargeMethod,
                suggestedMethod: bestAlternative.method,
                gapRatio: gapRatio
            ),
            suggestedTariffPricePerKWh: bestAlternative.averageTLPerKWh
        )
    }

    private func methodBenchmarks(
        sessions: [ChargingSession],
        electricityPricePerKWh: Double?
    ) -> [ChargeMethod: MethodBenchmark] {
        let recentSessions = Array(sessions.prefix(Constants.recentBenchmarkLimit))
        let grouped = Dictionary(grouping: recentSessions.compactMap { session -> (ChargeMethod, Double)? in
            guard let tlPerKWh = session.tlPerKWh, tlPerKWh > 0 else { return nil }
            return (session.chargeMethod, tlPerKWh)
        }, by: \.0)

        var result: [ChargeMethod: MethodBenchmark] = [:]

        for method in ChargeMethod.allCases {
            let methodValues = grouped[method]?.map(\.1) ?? []
            if !methodValues.isEmpty {
                result[method] = MethodBenchmark(
                    method: method,
                    averageTLPerKWh: methodValues.reduce(0, +) / Double(methodValues.count),
                    sampleCount: methodValues.count,
                    isEstimated: false
                )
            }
        }

        if result[.home] == nil,
           let electricityPricePerKWh,
           electricityPricePerKWh > 0 {
            result[.home] = MethodBenchmark(
                method: .home,
                averageTLPerKWh: electricityPricePerKWh,
                sampleCount: 1,
                isEstimated: true
            )
        }

        return result
    }

    private func recommendationReason(
        currentMethod: ChargeMethod,
        suggestedMethod: ChargeMethod,
        gapRatio: Double
    ) -> String {
        let deltaText = "%\(Int((gapRatio * 100).rounded()))"

        if suggestedMethod == .home {
            return "Ev şarjı son kullandığın \(currentMethod.titleTR) yöntemine göre yaklaşık \(deltaText) daha avantajlı görünüyor."
        }

        return "Son zamanlarda \(suggestedMethod.titleTR) daha avantajlı görünüyor. Son kullandığın \(currentMethod.titleTR) yöntemine göre yaklaşık \(deltaText) daha düşük birim maliyet veriyor."
    }
}
