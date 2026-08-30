import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@Model
public final class ChargingSessionRecord {
    @Attribute(.unique) public var id: UUID
    public var vehicleID: UUID
    public var sessionDate: Date
    public var chargeMethodRaw: String
    public var stationBrand: String?
    public var locationName: String?
    public var priceTotal: Double
    public var currencyCode: String
    public var energyKWh: Double?
    public var energyIsEstimated: Bool
    public var socStart: Double
    public var socEnd: Double
    public var isFullCharge: Bool
    public var durationMin: Int?
    public var odometerKM: Double?
    public var outsideTempC: Double?
    public var weatherCondition: String?
    public var rangeGainedKmEstimate: Double?
    public var contextTagsRaw: String?
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        vehicleID: UUID,
        sessionDate: Date,
        chargeMethodRaw: String,
        stationBrand: String?,
        locationName: String?,
        priceTotal: Double,
        currencyCode: String,
        energyKWh: Double?,
        energyIsEstimated: Bool,
        socStart: Double,
        socEnd: Double,
        isFullCharge: Bool,
        durationMin: Int?,
        odometerKM: Double?,
        outsideTempC: Double?,
        weatherCondition: String?,
        rangeGainedKmEstimate: Double?,
        contextTagsRaw: String?,
        notes: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.sessionDate = sessionDate
        self.chargeMethodRaw = chargeMethodRaw
        self.stationBrand = stationBrand
        self.locationName = locationName
        self.priceTotal = priceTotal
        self.currencyCode = currencyCode
        self.energyKWh = energyKWh
        self.energyIsEstimated = energyIsEstimated
        self.socStart = socStart
        self.socEnd = socEnd
        self.isFullCharge = isFullCharge
        self.durationMin = durationMin
        self.odometerKM = odometerKM
        self.outsideTempC = outsideTempC
        self.weatherCondition = weatherCondition
        self.rangeGainedKmEstimate = rangeGainedKmEstimate
        self.contextTagsRaw = contextTagsRaw
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
#endif
