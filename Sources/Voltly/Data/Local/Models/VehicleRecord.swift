import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@Model
public final class VehicleRecord {
    @Attribute(.unique) public var id: UUID
    public var brand: String
    public var model: String
    public var year: Int
    public var enginePowerHP: Double?
    public var enginePowerKW: Double?
    public var acMaxChargingKW: Double?
    public var dcMaxChargingKW: Double?
    public var batteryCapacityKWh: Double
    public var factoryConsumptionKWh100km: Double?
    public var colorCode: String?
    public var silhouetteKey: String?
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        brand: String,
        model: String,
        year: Int,
        enginePowerHP: Double?,
        enginePowerKW: Double?,
        acMaxChargingKW: Double?,
        dcMaxChargingKW: Double?,
        batteryCapacityKWh: Double,
        factoryConsumptionKWh100km: Double?,
        colorCode: String?,
        silhouetteKey: String?,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.year = year
        self.enginePowerHP = enginePowerHP
        self.enginePowerKW = enginePowerKW
        self.acMaxChargingKW = acMaxChargingKW
        self.dcMaxChargingKW = dcMaxChargingKW
        self.batteryCapacityKWh = batteryCapacityKWh
        self.factoryConsumptionKWh100km = factoryConsumptionKWh100km
        self.colorCode = colorCode
        self.silhouetteKey = silhouetteKey
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
#endif
