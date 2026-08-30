import Foundation

public struct ConsumptionEstimationInput: Equatable, Sendable {
    public let totalEnergyKWh: Double
    public let distanceResult: DistanceEstimationResult
    public let historicalConsumptionKWh100km: Double?
    public let factoryConsumptionKWh100km: Double?
    public let defaultConsumptionKWh100km: Double

    public init(
        totalEnergyKWh: Double,
        distanceResult: DistanceEstimationResult,
        historicalConsumptionKWh100km: Double?,
        factoryConsumptionKWh100km: Double?,
        defaultConsumptionKWh100km: Double
    ) {
        self.totalEnergyKWh = totalEnergyKWh
        self.distanceResult = distanceResult
        self.historicalConsumptionKWh100km = historicalConsumptionKWh100km
        self.factoryConsumptionKWh100km = factoryConsumptionKWh100km
        self.defaultConsumptionKWh100km = defaultConsumptionKWh100km
    }
}

public struct ConsumptionEstimationResult: Equatable, Sendable {
    public let avgConsumptionKWh100km: Double
    public let mode: ConsumptionCalculationMode
    public let warnings: [CalculationWarning]

    public init(
        avgConsumptionKWh100km: Double,
        mode: ConsumptionCalculationMode,
        warnings: [CalculationWarning]
    ) {
        self.avgConsumptionKWh100km = avgConsumptionKWh100km
        self.mode = mode
        self.warnings = warnings
    }
}

public struct ConsumptionEstimator {
    private enum DistanceBlocks {
        static let factoryFallbackUpperBoundKM = 500.0
        static let realDataLowerBoundKM = 1_000.0
    }

    private let validation: CalculationValidationService

    public init(validation: CalculationValidationService = .init()) {
        self.validation = validation
    }

    public func estimate(input: ConsumptionEstimationInput) -> ConsumptionEstimationResult {
        if let selectedBlock = input.distanceResult.selectedBlock {
            let blockConsumption = validation.safePer100(
                numerator: selectedBlock.totalEnergyKWh,
                denominator: selectedBlock.distanceKm
            )
            let fallback = fallbackConsumption(input: input)

            if validation.isValidConsumption(blockConsumption) {
                let mode: ConsumptionCalculationMode = selectedBlock.distanceKm >= DistanceBlocks.realDataLowerBoundKM
                    ? .realData
                    : .blockAverage
                return ConsumptionEstimationResult(
                    avgConsumptionKWh100km: blockConsumption ?? fallback.value,
                    mode: mode,
                    warnings: []
                )
            }

            var warnings = fallback.warnings
            if validation.hasPotentialConsumptionUnitInversion(blockConsumption) {
                warnings.append(
                    CalculationWarning(
                        id: "consumption.unit_inversion",
                        message: "Tuketim degerinde km/kWh ve kWh/km karisikligi olasiligina karsi koruma uygulandi."
                    )
                )
            }
            warnings.append(
                CalculationWarning(
                    id: "consumption.invalid",
                    message: "Secilen km blogundan guvenilir tuketim uretilemedigi icin tahmini tuketim kullanildi."
                )
            )
            return ConsumptionEstimationResult(
                avgConsumptionKWh100km: fallback.value,
                mode: fallback.mode,
                warnings: warnings
            )
        }

        let rawConsumption = validation.safePer100(
            numerator: input.totalEnergyKWh,
            denominator: input.distanceResult.estimatedDistanceKm
        )
        let reliableDistanceKm = input.distanceResult.reliableDistanceKm
        let fallback = fallbackConsumption(input: input)

        if input.distanceResult.mode == .energyEstimated {
            let mode = consumptionModeForReference(source: input.distanceResult.referenceSource)
            return ConsumptionEstimationResult(
                avgConsumptionKWh100km: fallback.value,
                mode: mode,
                warnings: fallback.warnings
            )
        }

        if validation.isValidConsumption(rawConsumption) {
            if reliableDistanceKm < DistanceBlocks.factoryFallbackUpperBoundKM {
                return ConsumptionEstimationResult(
                    avgConsumptionKWh100km: fallback.value,
                    mode: fallback.mode,
                    warnings: fallback.warnings
                )
            }

            let mode: ConsumptionCalculationMode = reliableDistanceKm >= DistanceBlocks.realDataLowerBoundKM
                ? .realData
                : .blockAverage
            return ConsumptionEstimationResult(
                avgConsumptionKWh100km: rawConsumption ?? fallback.value,
                mode: mode,
                warnings: []
            )
        }

        var warnings = fallback.warnings
        if validation.hasPotentialConsumptionUnitInversion(rawConsumption) {
            warnings.append(
                CalculationWarning(
                    id: "consumption.unit_inversion",
                    message: "Tuketim degerinde km/kWh ve kWh/km karisikligi olasiligina karsi koruma uygulandi."
                )
            )
        }
        warnings.append(
            CalculationWarning(
                id: "consumption.invalid",
                message: "Gercek tuketim hesabi guvenilir bulunmadi, tahmini tuketim kullanildi."
            )
        )
        return ConsumptionEstimationResult(
            avgConsumptionKWh100km: fallback.value,
            mode: fallback.mode,
            warnings: warnings
        )
    }

    private func fallbackConsumption(
        input: ConsumptionEstimationInput
    ) -> (value: Double, mode: ConsumptionCalculationMode, warnings: [CalculationWarning]) {
        if validation.isValidConsumption(input.factoryConsumptionKWh100km) {
            return (
                value: input.factoryConsumptionKWh100km ?? input.defaultConsumptionKWh100km,
                mode: .factoryEstimated,
                warnings: []
            )
        }

        if validation.isValidConsumption(input.historicalConsumptionKWh100km) {
            return (
                value: input.historicalConsumptionKWh100km ?? input.defaultConsumptionKWh100km,
                mode: .historicalEstimated,
                warnings: []
            )
        }

        return (
            value: input.defaultConsumptionKWh100km,
            mode: .defaultEstimated,
            warnings: [
                CalculationWarning(
                    id: "consumption.default",
                    message: "Yeterli km verisi olmadigi icin varsayilan tuketim kullanildi."
                )
            ]
        )
    }

    private func consumptionModeForReference(
        source: ConsumptionReferenceSource
    ) -> ConsumptionCalculationMode {
        switch source {
        case .historical:
            return .historicalEstimated
        case .factory:
            return .factoryEstimated
        case .default:
            return .defaultEstimated
        }
    }
}
