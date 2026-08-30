import Foundation

public struct FuelBaselineSettings: Equatable {
    public var fuelPricePerLiter: Double
    public var iceConsumptionLPer100Km: Double
    public var currencyCode: String
    public var electricityPricePerKWh: Double

    public init(
        fuelPricePerLiter: Double,
        iceConsumptionLPer100Km: Double,
        currencyCode: String = AppConstants.defaultCurrencyCode,
        electricityPricePerKWh: Double = AppConstants.defaultElectricityPricePerKWh
    ) {
        self.fuelPricePerLiter = fuelPricePerLiter
        self.iceConsumptionLPer100Km = iceConsumptionLPer100Km
        self.currencyCode = currencyCode
        self.electricityPricePerKWh = electricityPricePerKWh
    }
}
