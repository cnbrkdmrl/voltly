import Foundation

public struct SavingsCalculationEngine {
    private enum Constants {
        static let defaultConsumptionKWh100km = 18.5
        static let minimumEstimatedDistanceKM = 500.0
        static let minimumRealDistanceKM = 1_000.0
        static let maximumBlockDistanceKM = 3_000.0
    }

    private struct PreparedSession: Equatable {
        let session: ChargingSession
        let energyKWh: Double
        let effectiveCost: Double
        let usedPriceFallback: Bool
        let suspiciousReasons: [String]
    }

    private struct InvalidSessionInfo: Equatable {
        let date: Date
        let reasons: [String]
    }

    private struct WeightedBlockAggregate: Equatable {
        let totalEnergyKWh: Double
        let totalDistanceKm: Double
        let weightedConsumptionKWh100km: Double
        let mode: ConsumptionCalculationMode
    }

    private let validation: CalculationValidationService
    private let distanceEstimator: DistanceEstimator
    private let consumptionEstimator: ConsumptionEstimator
    private let gasolineCalculator: GasolineComparisonCalculator
    private let carbonCalculator: CarbonCalculator
    private let equivalentsCalculator: SavingsEquivalentsCalculator

    public init(
        validation: CalculationValidationService = .init(),
        distanceEstimator: DistanceEstimator = .init(),
        consumptionEstimator: ConsumptionEstimator = .init(),
        gasolineCalculator: GasolineComparisonCalculator = .init(),
        carbonCalculator: CarbonCalculator = .init(),
        equivalentsCalculator: SavingsEquivalentsCalculator = .init()
    ) {
        self.validation = validation
        self.distanceEstimator = distanceEstimator
        self.consumptionEstimator = consumptionEstimator
        self.gasolineCalculator = gasolineCalculator
        self.carbonCalculator = carbonCalculator
        self.equivalentsCalculator = equivalentsCalculator
    }

    public func calculate(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        preferences: FuelBaselineSettings,
        referenceDate: Date = .now
    ) -> SavingsCalculationReport {
        let sortedSessions = sessions
            .filter { $0.vehicleID == vehicle.id }
            .sorted { $0.sessionDate < $1.sessionDate }

        let prepared = prepareSessions(sortedSessions, preferences: preferences)
        let historicalConsumption = makeHistoricalReliableConsumption(from: prepared.valid)

        let summaries = Dictionary(uniqueKeysWithValues: SavingsCalculationPeriod.allCases.map { period in
            (
                period,
                makeSummary(
                    period: period,
                    validSessions: prepared.valid.filter { isInPeriod($0.session.sessionDate, period: period, referenceDate: referenceDate) },
                    invalidSessions: prepared.invalid.filter { isInPeriod($0.date, period: period, referenceDate: referenceDate) },
                    historicalConsumptionKWh100km: historicalConsumption,
                    vehicle: vehicle,
                    preferences: preferences
                )
            )
        })

        let allTime = summaries[.allTime]
        let thisMonth = summaries[.thisMonth]

        let piggyBank = equivalentsCalculator.calculate(
            savingsAmount: max(allTime?.savingsAmount ?? 0, 0),
            fuelPricePerLiter: preferences.fuelPricePerLiter
        )

        let allCarbon = carbonCalculator.calculate(distanceKm: allTime?.estimatedDistanceKm ?? 0)
        let monthlyCarbon = carbonCalculator.calculate(distanceKm: thisMonth?.estimatedDistanceKm ?? 0)
        let carbonSummary = CarbonSummary(
            avoidedCO2Kg: allCarbon.avoidedCO2Kg,
            equivalentTrees: allCarbon.equivalentTrees,
            monthlyAvoidedCO2Kg: monthlyCarbon.avoidedCO2Kg,
            label: "Tahmini karbon kacinimi"
        )

        return SavingsCalculationReport(
            summaries: summaries,
            savingsPiggyBank: piggyBank,
            carbonSummary: carbonSummary
        )
    }

    private func makeSummary(
        period: SavingsCalculationPeriod,
        validSessions: [PreparedSession],
        invalidSessions: [InvalidSessionInfo],
        historicalConsumptionKWh100km: Double?,
        vehicle: Vehicle,
        preferences: FuelBaselineSettings
    ) -> SavingsSummary {
        let totalEnergy = validSessions.reduce(0.0) { $0 + $1.energyKWh }
        let totalEvCost = validSessions.reduce(0.0) { $0 + $1.effectiveCost }
        let rawCostTotal = validSessions.reduce(0.0) { $0 + $1.session.priceTotal }
        let fallbackPriceCount = validSessions.filter(\.usedPriceFallback).count
        let suspiciousCount = validSessions.filter { !$0.suspiciousReasons.isEmpty }.count
        let weightedSamples: [DistanceEstimationInput.SessionSample] = validSessions.map {
            DistanceEstimationInput.SessionSample(
                id: $0.session.id,
                date: $0.session.sessionDate,
                energyKWh: $0.energyKWh,
                effectiveCost: $0.effectiveCost,
                odometerKM: $0.session.odometerKM,
                isSuspicious: !$0.suspiciousReasons.isEmpty
            )
        }

        let reference = resolveDistanceReferenceConsumption(
            historicalConsumptionKWh100km: historicalConsumptionKWh100km,
            factoryConsumptionKWh100km: vehicle.factoryConsumptionKWh100km
        )
        let distanceResult = distanceEstimator.estimate(
            input: DistanceEstimationInput(
                sessions: weightedSamples,
                referenceConsumptionKWh100Km: reference.value,
                referenceSource: reference.source
            )
        )

        let consumptionResult = consumptionEstimator.estimate(
            input: ConsumptionEstimationInput(
                totalEnergyKWh: totalEnergy,
                distanceResult: distanceResult,
                historicalConsumptionKWh100km: historicalConsumptionKWh100km,
                factoryConsumptionKWh100km: vehicle.factoryConsumptionKWh100km,
                defaultConsumptionKWh100km: Constants.defaultConsumptionKWh100km
            )
        )

        let weightedBlockAggregate = makeWeightedBlockAggregate(from: validSessions)
        let effectiveConsumption = weightedBlockAggregate?.weightedConsumptionKWh100km
            ?? consumptionResult.avgConsumptionKWh100km
        let effectiveConsumptionMode = weightedBlockAggregate?.mode
            ?? consumptionResult.mode
        let effectiveEstimatedDistanceKm = resolveEstimatedDistance(
            totalEnergyKWh: totalEnergy,
            avgConsumptionKWh100km: effectiveConsumption,
            fallbackDistanceKm: distanceResult.estimatedDistanceKm
        )
        let effectiveDistanceMode: DistanceCalculationMode = weightedBlockAggregate == nil
            ? distanceResult.mode
            : .odometer

        let gasolineResult = gasolineCalculator.calculate(
            totalEvCost: totalEvCost,
            estimatedDistanceKm: effectiveEstimatedDistanceKm,
            baseline: preferences
        )
        let effectiveEvCostPer100Km = validation.safePer100(
            numerator: totalEvCost,
            denominator: effectiveEstimatedDistanceKm
        )

        var warnings: [CalculationWarning] = []
        warnings.append(contentsOf: invalidSessions.map {
            CalculationWarning(
                id: "session.invalid.\($0.reasons.joined(separator: "_"))",
                message: "Bazi kayitlar analiz disinda birakildi: \($0.reasons.joined(separator: ", "))"
            )
        })
        warnings.append(contentsOf: consumptionResult.warnings)
        warnings.append(contentsOf: gasolineResult.warnings)
        warnings.append(contentsOf: distanceResult.invalidTransitionReasons.map {
            CalculationWarning(
                id: "distance.\($0)",
                message: "Km zincirinde supheli gecis filtrelendi."
            )
        })
        if fallbackPriceCount > 0 {
            warnings.append(
                CalculationWarning(
                    id: "price.fallback",
                    message: "Bazi kayitlarda fiyat eksik oldugu icin kullanici elektrik birim fiyati kullanildi."
                )
            )
        }
        if suspiciousCount > 0 {
            warnings.append(
                CalculationWarning(
                    id: "session.suspicious",
                    message: "Bazi supheli kayitlar guven skoruna ve fallback kararina dahil edildi."
                )
            )
        }

        let confidence = makeConfidenceReport(
            sessionCount: validSessions.count,
            suspiciousCount: suspiciousCount,
            invalidCount: invalidSessions.count,
            fallbackPriceCount: fallbackPriceCount,
            distanceMode: effectiveDistanceMode,
            consumptionMode: effectiveConsumptionMode
        )

        let mode = SavingsCalculationMode(
            distance: effectiveDistanceMode,
            consumption: effectiveConsumptionMode
        )
        let explanation = makeExplanation(
            mode: mode,
            invalidCount: invalidSessions.count,
            suspiciousCount: suspiciousCount
        )

        let costPerKWh = validation.safeRatio(
            numerator: totalEvCost,
            denominator: totalEnergy
        )

        let debugInfo: SavingsCalculationDebugInfo?
        #if DEBUG
            debugInfo = SavingsCalculationDebugInfo(
                rawSessionCount: validSessions.count + invalidSessions.count,
                validSessionCount: validSessions.count,
                suspiciousSessionCount: suspiciousCount,
                odometerPointCount: distanceResult.odometerPointCount,
                distanceSource: effectiveDistanceMode,
                consumptionSource: effectiveConsumptionMode,
                invalidReasons: invalidSessions.flatMap(\.reasons),
                fallbackTriggered: fallbackPriceCount > 0 || !consumptionResult.warnings.isEmpty,
                rawEnergyTotal: totalEnergy,
                rawCostTotal: rawCostTotal
            )
        #else
        debugInfo = nil
        #endif

        return SavingsSummary(
            period: period,
            totalEnergyKWh: totalEnergy,
            totalEvCost: totalEvCost,
            estimatedDistanceKm: max(effectiveEstimatedDistanceKm, 0),
            avgConsumptionKWh100km: effectiveConsumption,
            gasolineEquivalentCost: gasolineResult.gasolineEquivalentCost,
            savingsAmount: gasolineResult.savingsAmount,
            savingsPercent: gasolineResult.savingsPercent,
            evCostPer100Km: effectiveEvCostPer100Km ?? gasolineResult.evCostPer100Km,
            gasolineCostPer100Km: gasolineResult.gasolineCostPer100Km,
            costPerKWh: costPerKWh,
            sessionCount: validSessions.count,
            confidenceLevel: confidence.level,
            confidenceReport: confidence,
            calculationMode: mode,
            warnings: collapseWarnings(warnings),
            explanationText: explanation,
            consumptionLabel: consumptionLabel(for: consumptionResult.mode),
            debugInfo: debugInfo
        )
    }

    private func prepareSessions(
        _ sessions: [ChargingSession],
        preferences: FuelBaselineSettings
    ) -> (valid: [PreparedSession], invalid: [InvalidSessionInfo]) {
        var valid: [PreparedSession] = []
        var invalid: [InvalidSessionInfo] = []

        for session in sessions {
            var invalidReasons: [String] = []
            var suspiciousReasons: [String] = []

            guard let energy = session.energyKWh, energy.isFinite else {
                invalidReasons.append("energy_missing")
                invalid.append(.init(date: session.sessionDate, reasons: invalidReasons))
                continue
            }

            if energy < 2 {
                invalidReasons.append("energy_too_low")
            }
            if energy <= 0 {
                invalidReasons.append("energy_invalid")
            }
            if !session.priceTotal.isFinite {
                invalidReasons.append("price_invalid")
            }
            if session.priceTotal < 0 {
                invalidReasons.append("price_negative")
            }

            if !invalidReasons.isEmpty {
                invalid.append(.init(date: session.sessionDate, reasons: invalidReasons))
                continue
            }

            if validation.isSuspiciousSOC(start: session.socStart, end: session.socEnd) {
                suspiciousReasons.append("soc_suspicious")
            }
            if validation.isSuspiciousDurationEnergyPair(durationMin: session.durationMin, energyKWh: energy) {
                suspiciousReasons.append("duration_energy_suspicious")
            }
            if validation.isSuspiciousPricePerKWh(price: session.priceTotal, energyKWh: energy) {
                suspiciousReasons.append("unit_price_suspicious")
            }

            let usedPriceFallback = session.priceTotal <= 0
            let effectiveCost = usedPriceFallback
                ? energy * max(preferences.electricityPricePerKWh, 0)
                : session.priceTotal

            valid.append(
                PreparedSession(
                    session: session,
                    energyKWh: energy,
                    effectiveCost: max(0, effectiveCost),
                    usedPriceFallback: usedPriceFallback,
                    suspiciousReasons: suspiciousReasons
                )
            )
        }

        return (valid: valid, invalid: invalid)
    }

    private func makeHistoricalReliableConsumption(
        from sessions: [PreparedSession]
    ) -> Double? {
        let sorted = sessions.sorted { $0.session.sessionDate < $1.session.sessionDate }
        let odometerChain = sorted.filter { $0.session.odometerKM != nil }
        guard odometerChain.count >= 2 else { return nil }

        var totalEnergyKWh: Double = 0
        var totalDistanceKm: Double = 0

        for index in 1..<odometerChain.count {
            let previous = odometerChain[index - 1]
            let current = odometerChain[index]
            guard let previousOdometer = previous.session.odometerKM,
                  let currentOdometer = current.session.odometerKM else {
                continue
            }

            let distance = currentOdometer - previousOdometer
            let interval = current.session.sessionDate.timeIntervalSince(previous.session.sessionDate)
            guard validation.isPlausibleDistance(distance: distance, interval: interval) else {
                continue
            }

            guard validation.isValidEnergy(current.energyKWh) else {
                continue
            }

            totalEnergyKWh += current.energyKWh
            totalDistanceKm += distance
        }

        let weightedConsumption = validation.safePer100(
            numerator: totalEnergyKWh,
            denominator: totalDistanceKm
        )
        guard validation.isValidConsumption(weightedConsumption) else { return nil }
        return weightedConsumption
    }

    private func makeConfidenceReport(
        sessionCount: Int,
        suspiciousCount: Int,
        invalidCount: Int,
        fallbackPriceCount: Int,
        distanceMode: DistanceCalculationMode,
        consumptionMode: ConsumptionCalculationMode
    ) -> ConfidenceReport {
        var score = 100
        if sessionCount < 2 {
            score -= 30
        } else if sessionCount < 4 {
            score -= 15
        }

        switch distanceMode {
        case .odometer:
            break
        case .hybrid:
            score -= 15
        case .energyEstimated:
            score -= 30
        }

        switch consumptionMode {
        case .realData:
            break
        case .blockAverage:
            score -= 10
        case .historicalEstimated, .factoryEstimated:
            score -= 20
        case .defaultEstimated:
            score -= 25
        }

        if sessionCount > 0 {
            let suspiciousRatio = Double(suspiciousCount) / Double(sessionCount)
            if suspiciousRatio > 0.4 {
                score -= 25
            } else if suspiciousRatio > 0.2 {
                score -= 15
            } else if suspiciousRatio > 0 {
                score -= 8
            }

            let fallbackPriceRatio = Double(fallbackPriceCount) / Double(sessionCount)
            if fallbackPriceRatio > 0.4 {
                score -= 15
            } else if fallbackPriceRatio > 0 {
                score -= 8
            }
        }

        score -= min(20, invalidCount * 3)
        score = max(0, min(score, 100))

        let level: SavingsConfidenceLevel
        if score >= 75 {
            level = .high
        } else if score >= 45 {
            level = .medium
        } else {
            level = .low
        }

        let explanation: String
        switch level {
        case .high:
            explanation = "Analiz buyuk oranda gercek veriye dayaniyor."
        case .medium:
            explanation = "Analiz kismi tahminle destekleniyor."
        case .low:
            explanation = "Analizde tahmini veri agirligi yuksek."
        }

        return ConfidenceReport(level: level, score: score, explanation: explanation)
    }

    private func makeWeightedBlockAggregate(
        from sessions: [PreparedSession]
    ) -> WeightedBlockAggregate? {
        let sorted = sessions.sorted { $0.session.sessionDate < $1.session.sessionDate }
        guard !sorted.isEmpty else { return nil }

        var totalEnergyKWh: Double = 0
        var totalDistanceKm: Double = 0
        var realDistanceKm: Double = 0
        var endIndex = sorted.count - 1

        while endIndex >= 0 {
            let endSession = sorted[endIndex]
            guard let endOdometer = endSession.session.odometerKM else {
                endIndex -= 1
                continue
            }

            var candidates: [(startIndex: Int, deltaKm: Double, totalEnergyKWh: Double)] = []
            for startIndex in 0..<endIndex {
                let startSession = sorted[startIndex]
                guard let startOdometer = startSession.session.odometerKM else { continue }

                let deltaKm = endOdometer - startOdometer
                let interval = endSession.session.sessionDate.timeIntervalSince(startSession.session.sessionDate)
                guard validation.isPlausibleDistance(distance: deltaKm, interval: interval),
                      deltaKm >= Constants.minimumEstimatedDistanceKM,
                      deltaKm < Constants.maximumBlockDistanceKM else {
                    continue
                }

                let blockEnergy = sorted[startIndex...endIndex].reduce(0.0) { $0 + $1.energyKWh }
                let blockConsumption = validation.safePer100(
                    numerator: blockEnergy,
                    denominator: deltaKm
                )
                guard validation.isValidConsumption(blockConsumption) else {
                    continue
                }

                candidates.append(
                    (startIndex: startIndex, deltaKm: deltaKm, totalEnergyKWh: blockEnergy)
                )
            }

            let preferredCandidate = candidates
                .filter { $0.deltaKm >= Constants.minimumRealDistanceKM }
                .min(by: { $0.deltaKm < $1.deltaKm })
                ?? candidates.min(by: { $0.deltaKm < $1.deltaKm })

            guard let preferredCandidate else {
                endIndex -= 1
                continue
            }

            totalEnergyKWh += preferredCandidate.totalEnergyKWh
            totalDistanceKm += preferredCandidate.deltaKm
            if preferredCandidate.deltaKm >= Constants.minimumRealDistanceKM {
                realDistanceKm += preferredCandidate.deltaKm
            }
            endIndex = preferredCandidate.startIndex - 1
        }

        let weightedConsumption = validation.safePer100(
            numerator: totalEnergyKWh,
            denominator: totalDistanceKm
        )
        guard validation.isValidConsumption(weightedConsumption) else {
            return nil
        }

        let mode: ConsumptionCalculationMode = realDistanceKm >= Constants.minimumRealDistanceKM
            ? .realData
            : .blockAverage

        return WeightedBlockAggregate(
            totalEnergyKWh: totalEnergyKWh,
            totalDistanceKm: totalDistanceKm,
            weightedConsumptionKWh100km: weightedConsumption ?? Constants.defaultConsumptionKWh100km,
            mode: mode
        )
    }

    private func resolveEstimatedDistance(
        totalEnergyKWh: Double,
        avgConsumptionKWh100km: Double,
        fallbackDistanceKm: Double
    ) -> Double {
        guard let derivedDistance = validation.safeRatio(
            numerator: totalEnergyKWh * 100,
            denominator: avgConsumptionKWh100km
        ), derivedDistance > 0 else {
            return max(fallbackDistanceKm, 0)
        }
        return derivedDistance
    }

    private func resolveDistanceReferenceConsumption(
        historicalConsumptionKWh100km: Double?,
        factoryConsumptionKWh100km: Double?
    ) -> (value: Double, source: ConsumptionReferenceSource) {
        if validation.isValidConsumption(historicalConsumptionKWh100km) {
            return (historicalConsumptionKWh100km ?? Constants.defaultConsumptionKWh100km, .historical)
        }
        if validation.isValidConsumption(factoryConsumptionKWh100km) {
            return (factoryConsumptionKWh100km ?? Constants.defaultConsumptionKWh100km, .factory)
        }
        return (Constants.defaultConsumptionKWh100km, .default)
    }

    private func consumptionLabel(for mode: ConsumptionCalculationMode) -> String {
        switch mode {
        case .realData:
            return "Gercek veri ile hesaplandi"
        case .blockAverage:
            return "Blok ortalama ile hesaplandi"
        case .factoryEstimated:
            return "Fabrika verisine gore tahmini"
        case .historicalEstimated:
            return "Gecmis surus verisine gore tahmini"
        case .defaultEstimated:
            return "Varsayilan tuketim ile tahmini"
        }
    }

    private func makeExplanation(
        mode: SavingsCalculationMode,
        invalidCount: Int,
        suspiciousCount: Int
    ) -> String {
        var parts: [String] = []
        switch mode.distance {
        case .odometer:
            parts.append("Bu hesap gercek odometre verileri ile olusturuldu.")
        case .hybrid:
            parts.append("Bu hesap kismi odometre ve kismi enerji tahmini ile olusturuldu.")
        case .energyEstimated:
            parts.append("Bu hesap eksik km verisi nedeniyle tahmini mesafe ile olusturuldu.")
        }

        if mode.consumption == .factoryEstimated {
            parts.append("Tuketim degeri fabrika verisine gore tahmini hesaplandi.")
        } else if mode.consumption == .blockAverage {
            parts.append("Tuketim degeri 500-1000 km blok ortalamasi ile hesaplandi.")
        } else if mode.consumption == .historicalEstimated {
            parts.append("Tuketim degeri gecmis surus verisine gore tahmini hesaplandi.")
        } else if mode.consumption == .defaultEstimated {
            parts.append("Tuketim icin varsayilan deger kullanildi.")
        }

        if invalidCount > 0 || suspiciousCount > 0 {
            parts.append("Bazi supheli kayitlar analiz disinda birakildi.")
        }

        return parts.joined(separator: " ")
    }

    private func isInPeriod(
        _ date: Date,
        period: SavingsCalculationPeriod,
        referenceDate: Date
    ) -> Bool {
        switch period {
        case .thisMonth:
            return date >= referenceDate.startOfMonth && date <= referenceDate.endOfMonth
        case .last30Days:
            guard let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: referenceDate) else {
                return false
            }
            return date >= fromDate && date <= referenceDate
        case .last12Months:
            guard let fromDate = Calendar.current.date(byAdding: .month, value: -12, to: referenceDate) else {
                return false
            }
            return date >= fromDate && date <= referenceDate
        case .allTime:
            return true
        }
    }

    private func collapseWarnings(_ warnings: [CalculationWarning]) -> [CalculationWarning] {
        var seen: Set<String> = []
        var collapsed: [CalculationWarning] = []
        for warning in warnings {
            guard !seen.contains(warning.id) else { continue }
            seen.insert(warning.id)
            collapsed.append(warning)
        }
        return collapsed
    }
}
