import Foundation

public enum ConsumptionBlockConfidenceType: String, Codable, Equatable, CaseIterable, Sendable {
    case real = "REAL"
    case estimated = "ESTIMATED"
    case factory = "FACTORY"

    public var basisLabel: String {
        switch self {
        case .real:
            return "Gercek surus verine gore hesaplandi"
        case .estimated:
            return "Yaklasik hesaplandi (500+ km blok)"
        case .factory:
            return "Fabrika verisi kullanildi"
        }
    }
}

public struct ConsumptionBlock: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let userID: String
    public let vehicleID: UUID
    public let startRecordID: UUID?
    public let endRecordID: UUID
    public let startKM: Double?
    public let endKM: Double?
    public let deltaKM: Double
    public let totalKWh: Double
    public let totalCostTRY: Double
    public let kWhPer100Km: Double
    public let tryPer100Km: Double
    public let confidenceType: ConsumptionBlockConfidenceType
    public let calculationBasis: String
    public let isActive: Bool
    public let isDirty: Bool
    public let version: Int
    public let updatedAt: Date
    public let startDate: Date
    public let endDate: Date

    public init(
        id: UUID = UUID(),
        userID: String = "local-user",
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
        confidenceType: ConsumptionBlockConfidenceType,
        calculationBasis: String,
        isActive: Bool = true,
        isDirty: Bool = false,
        version: Int = 1,
        updatedAt: Date = .now,
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
        self.confidenceType = confidenceType
        self.calculationBasis = calculationBasis
        self.isActive = isActive
        self.isDirty = isDirty
        self.version = version
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.endDate = endDate
    }
}

public enum VehicleMetricSnapshotPeriod: String, Codable, Equatable, CaseIterable, Sendable {
    case last30Days = "last_30_days"
    case last365Days = "last_365_days"
    case allTime = "all_time"
}

public struct VehicleMetricSnapshot: Codable, Equatable, Sendable {
    public let vehicleID: UUID
    public let period: VehicleMetricSnapshotPeriod
    public let avgKWh100Km: Double?
    public let avgTRY100Km: Double?
    public let gasolineTRY100Km: Double?
    public let savingTRY100Km: Double?
    public let savingPercent: Double?
    public let basisLabel: String
    public let updatedAt: Date

    public init(
        vehicleID: UUID,
        period: VehicleMetricSnapshotPeriod,
        avgKWh100Km: Double?,
        avgTRY100Km: Double?,
        gasolineTRY100Km: Double?,
        savingTRY100Km: Double?,
        savingPercent: Double?,
        basisLabel: String,
        updatedAt: Date = .now
    ) {
        self.vehicleID = vehicleID
        self.period = period
        self.avgKWh100Km = avgKWh100Km
        self.avgTRY100Km = avgTRY100Km
        self.gasolineTRY100Km = gasolineTRY100Km
        self.savingTRY100Km = savingTRY100Km
        self.savingPercent = savingPercent
        self.basisLabel = basisLabel
        self.updatedAt = updatedAt
    }
}

public enum ChargeRecordEventType: String, Equatable, Sendable {
    case created
    case updated
    case deleted
}

public struct ChargeRecordEvent: Equatable, Sendable {
    public let type: ChargeRecordEventType
    public let sessionID: UUID
    public let vehicleID: UUID
    public let sessionDate: Date
    public let wasLatestByDate: Bool

    public init(
        type: ChargeRecordEventType,
        sessionID: UUID,
        vehicleID: UUID,
        sessionDate: Date,
        wasLatestByDate: Bool
    ) {
        self.type = type
        self.sessionID = sessionID
        self.vehicleID = vehicleID
        self.sessionDate = sessionDate
        self.wasLatestByDate = wasLatestByDate
    }
}

public struct ChargeMetricsRealtimeUpdate: Codable, Equatable, Sendable {
    public let vehicleID: UUID
    public let latestBlock: ConsumptionBlock?
    public let snapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot]
    public let invalidatedDashboard: Bool

    public init(
        vehicleID: UUID,
        latestBlock: ConsumptionBlock?,
        snapshots: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot],
        invalidatedDashboard: Bool
    ) {
        self.vehicleID = vehicleID
        self.latestBlock = latestBlock
        self.snapshots = snapshots
        self.invalidatedDashboard = invalidatedDashboard
    }
}
