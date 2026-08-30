import Foundation

public struct CalculationValidationService {
    public struct ConsumptionRange: Equatable, Sendable {
        public let min: Double
        public let max: Double

        public init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }

        public func contains(_ value: Double) -> Bool {
            value >= min && value <= max
        }
    }

    private enum Constants {
        static let minNonTrivialEnergyKWh = 2.0
        static let maxDistancePerSessionKM = 2_500.0
        static let maxDistancePerDayKM = 1_200.0
        static let potentialUnitInversionThreshold = 5.0
    }

    public let validConsumptionRange: ConsumptionRange

    public init(validConsumptionRange: ConsumptionRange = .init(min: 5, max: 40)) {
        self.validConsumptionRange = validConsumptionRange
    }

    public func isValidEnergy(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value >= Constants.minNonTrivialEnergyKWh
    }

    public func isSuspiciousSOC(start: Double, end: Double) -> Bool {
        if start == 0, end == 0 { return true }
        return start == end
    }

    public func isSuspiciousDurationEnergyPair(durationMin: Int?, energyKWh: Double?) -> Bool {
        guard let durationMin, let energyKWh else { return false }
        if durationMin >= 300, energyKWh < 3 { return true }
        if durationMin <= 10, energyKWh >= 40 { return true }
        return false
    }

    public func isSuspiciousPricePerKWh(price: Double, energyKWh: Double?) -> Bool {
        guard let energyKWh, energyKWh > 0 else { return false }
        let unitPrice = price / energyKWh
        if !unitPrice.isFinite { return true }
        return unitPrice < 0.5 || unitPrice > 50
    }

    public func isValidPositive(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value > 0
    }

    public func safeRatio(
        numerator: Double,
        denominator: Double
    ) -> Double? {
        guard numerator.isFinite, denominator.isFinite, denominator > 0 else { return nil }
        let result = numerator / denominator
        guard result.isFinite else { return nil }
        return result
    }

    public func safePer100(
        numerator: Double,
        denominator: Double
    ) -> Double? {
        guard let ratio = safeRatio(numerator: numerator, denominator: denominator) else {
            return nil
        }
        let result = ratio * 100
        guard result.isFinite else { return nil }
        return result
    }

    public func isValidConsumption(_ value: Double?) -> Bool {
        guard let value else { return false }
        guard value.isFinite, value > 0 else { return false }
        return validConsumptionRange.contains(value)
    }

    public func hasPotentialConsumptionUnitInversion(_ value: Double?) -> Bool {
        guard let value, value.isFinite, value > 0 else { return false }
        return value < Constants.potentialUnitInversionThreshold
    }

    public func isPlausibleDistance(
        distance: Double,
        interval: TimeInterval
    ) -> Bool {
        guard distance.isFinite,
              distance > 0,
              distance <= Constants.maxDistancePerSessionKM else {
            return false
        }

        let intervalDays = max(interval / 86_400, 1.0 / 24.0)
        let maxPlausibleDistance = max(
            Constants.maxDistancePerDayKM,
            intervalDays * Constants.maxDistancePerDayKM
        )
        return distance <= maxPlausibleDistance
    }
}
