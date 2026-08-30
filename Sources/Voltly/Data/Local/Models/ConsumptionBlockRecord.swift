import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@Model
public final class ConsumptionBlockRecord {
    @Attribute(.unique) public var id: UUID
    public var userID: String
    public var vehicleID: UUID
    public var startRecordID: UUID?
    public var endRecordID: UUID
    public var startKM: Double?
    public var endKM: Double?
    public var deltaKM: Double
    public var totalKWh: Double
    public var totalCostTRY: Double
    public var kWhPer100Km: Double
    public var tryPer100Km: Double
    public var confidenceTypeRaw: String
    public var calculationBasis: String
    public var isActive: Bool
    public var isDirty: Bool
    public var version: Int
    public var updatedAt: Date
    public var startDate: Date
    public var endDate: Date

    public init(
        id: UUID,
        userID: String,
        vehicleID: UUID,
        startRecordID: UUID?,
        endRecordID: UUID,
        startKM: Double?,
        endKM: Double?,
        deltaKM: Double,
        totalKWh: Double,
        totalCostTRY: Double,
        kWhPer100Km: Double,
        tryPer100Km: Double,
        confidenceTypeRaw: String,
        calculationBasis: String,
        isActive: Bool,
        isDirty: Bool,
        version: Int,
        updatedAt: Date,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.userID = userID
        self.vehicleID = vehicleID
        self.startRecordID = startRecordID
        self.endRecordID = endRecordID
        self.startKM = startKM
        self.endKM = endKM
        self.deltaKM = deltaKM
        self.totalKWh = totalKWh
        self.totalCostTRY = totalCostTRY
        self.kWhPer100Km = kWhPer100Km
        self.tryPer100Km = tryPer100Km
        self.confidenceTypeRaw = confidenceTypeRaw
        self.calculationBasis = calculationBasis
        self.isActive = isActive
        self.isDirty = isDirty
        self.version = version
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.endDate = endDate
    }
}
#endif
