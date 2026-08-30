import Foundation

public struct GasolineComparisonResult: Equatable, Sendable {
    public let gasolineCostPer100Km: Double?
    public let gasolineEquivalentCost: Double
    public let savingsAmount: Double
    public let savingsPercent: Double?
    public let evCostPer100Km: Double?
    public let warnings: [CalculationWarning]

    public init(
        gasolineCostPer100Km: Double?,
        gasolineEquivalentCost: Double,
        savingsAmount: Double,
        savingsPercent: Double?,
        evCostPer100Km: Double?,
        warnings: [CalculationWarning]
    ) {
        self.gasolineCostPer100Km = gasolineCostPer100Km
        self.gasolineEquivalentCost = gasolineEquivalentCost
        self.savingsAmount = savingsAmount
        self.savingsPercent = savingsPercent
        self.evCostPer100Km = evCostPer100Km
        self.warnings = warnings
    }
}

public struct GasolineComparisonCalculator {
    private let validation: CalculationValidationService

    public init(validation: CalculationValidationService = .init()) {
        self.validation = validation
    }

    public func calculate(
        totalEvCost: Double,
        estimatedDistanceKm: Double,
        baseline: FuelBaselineSettings
    ) -> GasolineComparisonResult {
        var warnings: [CalculationWarning] = []

        let evCostPer100Km = validation.safePer100(
            numerator: totalEvCost,
            denominator: estimatedDistanceKm
        )

        let gasolineCostPer100Km = validation.safeRatio(
            numerator: baseline.fuelPricePerLiter * baseline.iceConsumptionLPer100Km,
            denominator: 1
        )

        guard let gasolineCostPer100Km,
              validation.isValidPositive(estimatedDistanceKm) else {
            warnings.append(
                CalculationWarning(
                    id: "gasoline.invalid_baseline",
                    message: "Benzin esdegeri icin yakit ayarlari gecersiz oldugu icin yuzde hesaplanamadi."
                )
            )
            return GasolineComparisonResult(
                gasolineCostPer100Km: nil,
                gasolineEquivalentCost: 0,
                savingsAmount: -totalEvCost,
                savingsPercent: nil,
                evCostPer100Km: evCostPer100Km,
                warnings: warnings
            )
        }

        let gasolineEquivalentCost = (estimatedDistanceKm / 100) * gasolineCostPer100Km
        let savingsAmount = gasolineEquivalentCost - totalEvCost
        let savingsRatio = validation.safeRatio(
            numerator: savingsAmount,
            denominator: gasolineEquivalentCost
        )
        let normalizedPercent = savingsRatio.map { $0 * 100 }

        return GasolineComparisonResult(
            gasolineCostPer100Km: gasolineCostPer100Km,
            gasolineEquivalentCost: gasolineEquivalentCost,
            savingsAmount: savingsAmount,
            savingsPercent: normalizedPercent,
            evCostPer100Km: evCostPer100Km,
            warnings: warnings
        )
    }
}
