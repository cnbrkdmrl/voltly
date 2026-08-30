import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@Model
public final class VehicleMetricSnapshotRecord {
    @Attribute(.unique) public var id: String
    public var vehicleID: UUID
    public var periodRaw: String
    public var avgKWh100Km: Double?
    public var avgTRY100Km: Double?
    public var gasolineTRY100Km: Double?
    public var savingTRY100Km: Double?
    public var savingPercent: Double?
    public var basisLabel: String
    public var updatedAt: Date

    public init(
        id: String,
        vehicleID: UUID,
        periodRaw: String,
        avgKWh100Km: Double?,
        avgTRY100Km: Double?,
        gasolineTRY100Km: Double?,
        savingTRY100Km: Double?,
        savingPercent: Double?,
        basisLabel: String,
        updatedAt: Date
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.periodRaw = periodRaw
        self.avgKWh100Km = avgKWh100Km
        self.avgTRY100Km = avgTRY100Km
        self.gasolineTRY100Km = gasolineTRY100Km
        self.savingTRY100Km = savingTRY100Km
        self.savingPercent = savingPercent
        self.basisLabel = basisLabel
        self.updatedAt = updatedAt
    }
}
#endif
