import Foundation

private struct LegacyOdometerBlock {
    let distanceKm: Double
    let totalEnergyKWh: Double
    let totalCost: Double
    let hasEstimatedEnergy: Bool
}

private enum LegacyOdometerBlockSelector {
    static let minimumEstimatedDistanceKM = 500.0
    static let minimumRealDistanceKM = 1_000.0
    static let maximumDistanceKM = 3_000.0

    static func select(
        sessions: [ChargingSession],
        validation: CalculationValidationService
    ) -> LegacyOdometerBlock? {
        let sorted = sessions.sorted { $0.sessionDate < $1.sessionDate }
        let odometerSessions = sorted.filter { $0.odometerKM != nil }

        guard let current = odometerSessions.last,
              let currentOdometer = current.odometerKM else {
            return nil
        }

        let candidates = odometerSessions.dropLast().compactMap { past -> LegacyOdometerBlock? in
            guard let pastOdometer = past.odometerKM else { return nil }

            let deltaKm = currentOdometer - pastOdometer
            let interval = current.sessionDate.timeIntervalSince(past.sessionDate)
            guard validation.isPlausibleDistance(distance: deltaKm, interval: interval),
                  deltaKm >= minimumEstimatedDistanceKM,
                  deltaKm < maximumDistanceKM else {
                return nil
            }

            let blockSessions = sorted.filter { session in
                session.sessionDate >= past.sessionDate && session.sessionDate <= current.sessionDate
            }

            let totalEnergy = blockSessions.reduce(0.0) { total, session in
                total + max(session.energyKWh ?? 0, 0)
            }
            let totalCost = blockSessions.reduce(0.0) { $0 + max($1.priceTotal, 0) }
            let hasEstimatedEnergy = blockSessions.contains(where: \.energyIsEstimated)

            guard totalEnergy > 0 else { return nil }

            return LegacyOdometerBlock(
                distanceKm: deltaKm,
                totalEnergyKWh: totalEnergy,
                totalCost: totalCost,
                hasEstimatedEnergy: hasEstimatedEnergy
            )
        }

        if let realCandidate = candidates
            .filter({ $0.distanceKm >= minimumRealDistanceKM })
            .min(by: { $0.distanceKm < $1.distanceKm }) {
            return realCandidate
        }

        return candidates.min(by: { $0.distanceKm < $1.distanceKm })
    }
}

public struct CalculateEstimatedEnergyUseCase {
    public init() {}

    public func execute(batteryCapacityKWh: Double, socStart: Double, socEnd: Double) -> Double {
        let delta = max(0, socEnd - socStart)
        return batteryCapacityKWh * (delta / 100.0)
    }
}

public struct CalculateTLPerKWhUseCase {
    public init() {}

    public func execute(priceTotal: Double, energyKWh: Double) -> Double? {
        guard energyKWh > 0 else { return nil }
        return priceTotal / energyKWh
    }
}

public struct CalculateEnergyPer100KmUseCase {
    private let validation = CalculationValidationService()

    public init() {}

    public func execute(sessions: [ChargingSession]) -> MeasuredValue<Double>? {
        guard let block = LegacyOdometerBlockSelector.select(
            sessions: sessions,
            validation: validation
        ) else {
            return nil
        }

        let value = (block.totalEnergyKWh / block.distanceKm) * 100
        guard validation.isValidConsumption(value) else { return nil }
        let isEstimated = block.distanceKm < LegacyOdometerBlockSelector.minimumRealDistanceKM || block.hasEstimatedEnergy
        return isEstimated ? .estimated(value) : .exact(value)
    }
}

public struct CalculateTLPer100KmUseCase {
    private let validation = CalculationValidationService()

    public init() {}

    public func execute(
        vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> MeasuredValue<Double>? {
        let sorted = sessions.sorted { $0.sessionDate < $1.sessionDate }

        if let block = LegacyOdometerBlockSelector.select(
            sessions: sorted,
            validation: validation
        ) {
            let consumption = (block.totalEnergyKWh / block.distanceKm) * 100
            guard validation.isValidConsumption(consumption) else { return nil }

            let tlPer100 = (block.totalCost / block.distanceKm) * 100
            let isEstimated = block.distanceKm < LegacyOdometerBlockSelector.minimumRealDistanceKM || block.hasEstimatedEnergy
            return isEstimated ? .estimated(tlPer100) : .exact(tlPer100)
        }

        // 2) Energy-based from actual/estimated charge energy.
        let energySessions = sorted.filter { ($0.energyKWh ?? 0) > 0 }
        let totalEnergy = energySessions.reduce(0) { $0 + ($1.energyKWh ?? 0) }
        let totalCost = energySessions.reduce(0) { $0 + $1.priceTotal }

        if totalEnergy > 0, totalCost >= 0 {
            let tlPerKWh = totalCost / totalEnergy
            if let factoryConsumption = vehicle.factoryConsumptionKWh100km, factoryConsumption > 0 {
                let result = tlPerKWh * factoryConsumption
                return .estimated(result)
            }
        }

        // 3) Fallback to factory consumption estimate with any available TL/kWh signal.
        guard let factoryConsumption = vehicle.factoryConsumptionKWh100km,
              factoryConsumption > 0,
              totalEnergy > 0 else {
            return nil
        }

        let fallbackTLPerKWh = totalCost / totalEnergy
        return .estimated(fallbackTLPerKWh * factoryConsumption)
    }
}

public struct CalculateGasolineComparisonUseCase {
    public init() {}

    public func execute(
        tlPer100km: Double,
        baseline: FuelBaselineSettings
    ) -> (percentCheaper: Double, savingsAmount: Double)? {
        let gasolineCost = baseline.fuelPricePerLiter * baseline.iceConsumptionLPer100Km
        guard gasolineCost > 0 else { return nil }
        let savings = gasolineCost - tlPer100km
        let percent = (savings / gasolineCost) * 100
        return (percent, savings)
    }
}

public struct EstimateDrivingDistanceUseCase {
    private enum Limits {
        static let maxDistancePerDayKM: Double = 1_200
        static let maxDistancePerSessionKM: Double = 2_500
        static let maxOdometerToEnergyRatio: Double = 2.5
        static let minOdometerToEnergyRatio: Double = 0.25
    }

    public init() {}

    public func execute(sessions: [ChargingSession], vehicle: Vehicle) -> Double {
        let energyDistance = energyDerivedDistance(from: sessions, vehicle: vehicle)

        if let odometerDistance = odometerDerivedDistance(from: sessions),
           odometerDistance > 0 {
            if let energyDistance, energyDistance > 0 {
                let ratio = odometerDistance / energyDistance
                if ratio >= Limits.minOdometerToEnergyRatio,
                   ratio <= Limits.maxOdometerToEnergyRatio {
                    return odometerDistance
                }
                return energyDistance
            }
            return odometerDistance
        }

        return energyDistance ?? 0
    }

    private func odometerDerivedDistance(from sessions: [ChargingSession]) -> Double? {
        let odometerSeries = sessions
            .compactMap { session -> (date: Date, odometer: Double)? in
                guard let odometer = session.odometerKM else { return nil }
                return (date: session.sessionDate, odometer: odometer)
            }
            .sorted { $0.date < $1.date }

        guard odometerSeries.count >= 2 else { return nil }

        var distanceTotal: Double = 0
        for index in 1..<odometerSeries.count {
            let previous = odometerSeries[index - 1]
            let next = odometerSeries[index]
            let distance = next.odometer - previous.odometer
            guard distance > 0 else { continue }
            guard distance <= Limits.maxDistancePerSessionKM else { continue }

            let interval = max(next.date.timeIntervalSince(previous.date), 3600)
            let intervalDays = interval / 86_400
            let maxPlausibleDistance = max(Limits.maxDistancePerDayKM, intervalDays * Limits.maxDistancePerDayKM)
            guard distance <= maxPlausibleDistance else { continue }

            distanceTotal += distance
        }

        guard distanceTotal > 0 else { return nil }
        return distanceTotal
    }

    private func energyDerivedDistance(from sessions: [ChargingSession], vehicle: Vehicle) -> Double? {
        guard let factoryConsumption = vehicle.factoryConsumptionKWh100km,
              factoryConsumption > 0 else {
            return nil
        }

        let totalEnergy = sessions
            .compactMap(\.energyKWh)
            .filter { $0 > 0 }
            .reduce(0, +)
        guard totalEnergy > 0 else { return nil }

        return (totalEnergy / factoryConsumption) * 100
    }
}
