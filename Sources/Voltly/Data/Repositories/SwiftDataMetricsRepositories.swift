import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public final class SwiftDataConsumptionBlockRepository: ConsumptionBlockRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchActive(vehicleID: UUID) throws -> [ConsumptionBlock] {
        let descriptor = FetchDescriptor<ConsumptionBlockRecord>(
            sortBy: [SortDescriptor(\ConsumptionBlockRecord.endDate)]
        )
        return try context.fetch(descriptor)
            .filter { $0.vehicleID == vehicleID && $0.isActive }
            .map(mapBlock)
    }

    public func replaceActive(vehicleID: UUID, blocks: [ConsumptionBlock]) throws {
        let descriptor = FetchDescriptor<ConsumptionBlockRecord>()
        let existing = try context.fetch(descriptor).filter { $0.vehicleID == vehicleID }
        for record in existing {
            context.delete(record)
        }

        for block in blocks.sorted(by: { $0.endDate < $1.endDate }) {
            context.insert(makeRecord(from: block))
        }
        try context.save()
    }

    public func markDirty(vehicleID: UUID, touching recordIDs: Set<UUID>) throws {
        guard !recordIDs.isEmpty else { return }
        let descriptor = FetchDescriptor<ConsumptionBlockRecord>()
        let existing = try context.fetch(descriptor).filter { $0.vehicleID == vehicleID }
        for record in existing {
            let touches = recordIDs.contains(record.endRecordID) || (record.startRecordID.map(recordIDs.contains) ?? false)
            guard touches else { continue }
            record.isDirty = true
            record.version += 1
            record.updatedAt = .now
        }
        try context.save()
    }

    private func makeRecord(from block: ConsumptionBlock) -> ConsumptionBlockRecord {
        ConsumptionBlockRecord(
            id: block.id,
            userID: block.userID,
            vehicleID: block.vehicleID,
            startRecordID: block.startRecordID,
            endRecordID: block.endRecordID,
            startKM: block.startKM,
            endKM: block.endKM,
            deltaKM: block.deltaKM,
            totalKWh: block.totalKWh,
            totalCostTRY: block.totalCostTRY,
            kWhPer100Km: block.kWhPer100Km,
            tryPer100Km: block.tryPer100Km,
            confidenceTypeRaw: block.confidenceType.rawValue,
            calculationBasis: block.calculationBasis,
            isActive: block.isActive,
            isDirty: block.isDirty,
            version: block.version,
            updatedAt: block.updatedAt,
            startDate: block.startDate,
            endDate: block.endDate
        )
    }

    private func mapBlock(_ record: ConsumptionBlockRecord) -> ConsumptionBlock {
        ConsumptionBlock(
            id: record.id,
            userID: record.userID,
            vehicleID: record.vehicleID,
            startRecordID: record.startRecordID,
            endRecordID: record.endRecordID,
            startKM: record.startKM,
            endKM: record.endKM,
            deltaKM: record.deltaKM,
            totalKWh: record.totalKWh,
            totalCostTRY: record.totalCostTRY,
            kWhPer100Km: record.kWhPer100Km,
            tryPer100Km: record.tryPer100Km,
            confidenceType: ConsumptionBlockConfidenceType(rawValue: record.confidenceTypeRaw) ?? .factory,
            calculationBasis: record.calculationBasis,
            isActive: record.isActive,
            isDirty: record.isDirty,
            version: record.version,
            updatedAt: record.updatedAt,
            startDate: record.startDate,
            endDate: record.endDate
        )
    }
}

public final class SwiftDataVehicleMetricSnapshotRepository: VehicleMetricSnapshotRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(vehicleID: UUID) throws -> [VehicleMetricSnapshot] {
        let descriptor = FetchDescriptor<VehicleMetricSnapshotRecord>()
        return try context.fetch(descriptor)
            .filter { $0.vehicleID == vehicleID }
            .compactMap(mapSnapshot)
            .sorted { $0.period.rawValue < $1.period.rawValue }
    }

    public func fetch(vehicleID: UUID, period: VehicleMetricSnapshotPeriod) throws -> VehicleMetricSnapshot? {
        try fetchAll(vehicleID: vehicleID).first { $0.period == period }
    }

    public func replace(vehicleID: UUID, snapshots: [VehicleMetricSnapshot]) throws {
        let descriptor = FetchDescriptor<VehicleMetricSnapshotRecord>()
        let existing = try context.fetch(descriptor).filter { $0.vehicleID == vehicleID }
        for record in existing {
            context.delete(record)
        }

        for snapshot in snapshots {
            context.insert(makeRecord(from: snapshot))
        }
        try context.save()
    }

    private func makeRecord(from snapshot: VehicleMetricSnapshot) -> VehicleMetricSnapshotRecord {
        VehicleMetricSnapshotRecord(
            id: recordID(vehicleID: snapshot.vehicleID, period: snapshot.period),
            vehicleID: snapshot.vehicleID,
            periodRaw: snapshot.period.rawValue,
            avgKWh100Km: snapshot.avgKWh100Km,
            avgTRY100Km: snapshot.avgTRY100Km,
            gasolineTRY100Km: snapshot.gasolineTRY100Km,
            savingTRY100Km: snapshot.savingTRY100Km,
            savingPercent: snapshot.savingPercent,
            basisLabel: snapshot.basisLabel,
            updatedAt: snapshot.updatedAt
        )
    }

    private func mapSnapshot(_ record: VehicleMetricSnapshotRecord) -> VehicleMetricSnapshot? {
        guard let period = VehicleMetricSnapshotPeriod(rawValue: record.periodRaw) else { return nil }
        return VehicleMetricSnapshot(
            vehicleID: record.vehicleID,
            period: period,
            avgKWh100Km: record.avgKWh100Km,
            avgTRY100Km: record.avgTRY100Km,
            gasolineTRY100Km: record.gasolineTRY100Km,
            savingTRY100Km: record.savingTRY100Km,
            savingPercent: record.savingPercent,
            basisLabel: record.basisLabel,
            updatedAt: record.updatedAt
        )
    }

    private func recordID(vehicleID: UUID, period: VehicleMetricSnapshotPeriod) -> String {
        "\(vehicleID.uuidString)-\(period.rawValue)"
    }
}
#endif
