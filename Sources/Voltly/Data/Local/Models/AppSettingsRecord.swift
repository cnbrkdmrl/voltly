import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@Model
public final class AppSettingsRecord {
    @Attribute(.unique) public var key: String
    public var fuelPricePerLiter: Double
    public var iceConsumptionLPer100Km: Double
    public var currencyCode: String
    public var electricityPricePerKWh: Double

    public init(
        key: String,
        fuelPricePerLiter: Double,
        iceConsumptionLPer100Km: Double,
        currencyCode: String,
        electricityPricePerKWh: Double
    ) {
        self.key = key
        self.fuelPricePerLiter = fuelPricePerLiter
        self.iceConsumptionLPer100Km = iceConsumptionLPer100Km
        self.currencyCode = currencyCode
        self.electricityPricePerKWh = electricityPricePerKWh
    }
}
#endif
