import Foundation

public protocol ConsumptionBlockRepository {
    func fetchActive(vehicleID: UUID) throws -> [ConsumptionBlock]
    func replaceActive(vehicleID: UUID, blocks: [ConsumptionBlock]) throws
    func markDirty(vehicleID: UUID, touching recordIDs: Set<UUID>) throws
}

public protocol VehicleMetricSnapshotRepository {
    func fetchAll(vehicleID: UUID) throws -> [VehicleMetricSnapshot]
    func fetch(vehicleID: UUID, period: VehicleMetricSnapshotPeriod) throws -> VehicleMetricSnapshot?
    func replace(vehicleID: UUID, snapshots: [VehicleMetricSnapshot]) throws
}
