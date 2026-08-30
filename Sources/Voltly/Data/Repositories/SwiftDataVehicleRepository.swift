import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public final class SwiftDataVehicleRepository: VehicleRepository {
    private let context: ModelContext
    private let vehicleCatalog: ReferenceVehicleCatalogProviding

    public init(
        context: ModelContext,
        vehicleCatalog: ReferenceVehicleCatalogProviding = StaticReferenceVehicleCatalog()
    ) {
        self.context = context
        self.vehicleCatalog = vehicleCatalog
    }

    public func fetchVehicles() throws -> [Vehicle] {
        let descriptor = FetchDescriptor<VehicleRecord>(sortBy: [SortDescriptor(\VehicleRecord.updatedAt, order: .reverse)])
        let records = try context.fetch(descriptor)
        if try enrichVehicleRecordsIfNeeded(records) {
            return try fetchVehicles()
        }
        return records.map(DomainMappers.map)
    }

    public func fetchActiveVehicle() throws -> Vehicle? {
        let descriptor = FetchDescriptor<VehicleRecord>(sortBy: [SortDescriptor(\VehicleRecord.updatedAt, order: .reverse)])
        let records = try context.fetch(descriptor)

        if try enrichVehicleRecordsIfNeeded(records) {
            return try fetchActiveVehicle()
        }

        if let activeRecord = records.first(where: { $0.isActive }) {
            if try repairActiveVehicleSelectionIfNeeded(records: records, activeRecord: activeRecord) {
                return try fetchActiveVehicle()
            }
            return DomainMappers.map(activeRecord)
        }

        guard let fallbackRecord = records.first else {
            return nil
        }

        for record in records {
            record.isActive = (record.id == fallbackRecord.id)
            record.updatedAt = .now
        }
        try context.save()

        return DomainMappers.map(fallbackRecord)
    }

    public func upsert(vehicle: Vehicle) throws {
        let record = try findRecord(by: vehicle.id) ?? VehicleRecord(
            id: vehicle.id,
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            enginePowerHP: vehicle.enginePowerHP,
            enginePowerKW: vehicle.enginePowerKW,
            acMaxChargingKW: vehicle.acMaxChargingKW,
            dcMaxChargingKW: vehicle.dcMaxChargingKW,
            batteryCapacityKWh: vehicle.batteryCapacityKWh,
            factoryConsumptionKWh100km: vehicle.factoryConsumptionKWh100km,
            colorCode: vehicle.colorCode,
            silhouetteKey: vehicle.silhouetteKey,
            isActive: vehicle.isActive,
            createdAt: vehicle.createdAt,
            updatedAt: vehicle.updatedAt
        )

        record.brand = vehicle.brand
        record.model = vehicle.model
        record.year = vehicle.year
        record.enginePowerHP = vehicle.enginePowerHP
        record.enginePowerKW = vehicle.enginePowerKW
        record.acMaxChargingKW = vehicle.acMaxChargingKW
        record.dcMaxChargingKW = vehicle.dcMaxChargingKW
        record.batteryCapacityKWh = vehicle.batteryCapacityKWh
        record.factoryConsumptionKWh100km = vehicle.factoryConsumptionKWh100km
        record.colorCode = vehicle.colorCode
        record.silhouetteKey = vehicle.silhouetteKey
        record.isActive = vehicle.isActive
        record.updatedAt = .now

        if record.modelContext == nil {
            context.insert(record)
        }
        try context.save()
    }

    public func delete(vehicleID: UUID) throws {
        if let record = try findRecord(by: vehicleID) {
            context.delete(record)
            try context.save()
        }
    }

    public func setActiveVehicle(id: UUID) throws {
        let descriptor = FetchDescriptor<VehicleRecord>()
        let records = try context.fetch(descriptor)
        for record in records {
            record.isActive = record.id == id
            record.updatedAt = .now
        }
        try context.save()
    }

    private func findRecord(by id: UUID) throws -> VehicleRecord? {
        let descriptor = FetchDescriptor<VehicleRecord>()
        return try context.fetch(descriptor).first(where: { $0.id == id })
    }

    private func repairActiveVehicleSelectionIfNeeded(
        records: [VehicleRecord],
        activeRecord: VehicleRecord
    ) throws -> Bool {
        let sessions = try context.fetch(FetchDescriptor<ChargingSessionRecord>())
        guard !sessions.isEmpty else {
            return false
        }

        let sessionCountByVehicle = Dictionary(
            sessions.map { ($0.vehicleID, 1) },
            uniquingKeysWith: +
        )
        let activeSessionCount = sessionCountByVehicle[activeRecord.id, default: 0]
        guard activeSessionCount == 0 else {
            return false
        }

        guard let fallbackRecord = records
            .filter({ $0.id != activeRecord.id && sessionCountByVehicle[$0.id, default: 0] > 0 })
            .max(by: { lhs, rhs in
                let lhsLatest = sessions
                    .filter { $0.vehicleID == lhs.id }
                    .map(\.sessionDate)
                    .max() ?? .distantPast
                let rhsLatest = sessions
                    .filter { $0.vehicleID == rhs.id }
                    .map(\.sessionDate)
                    .max() ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest < rhsLatest
                }
                return lhs.updatedAt < rhs.updatedAt
            }) else {
            return false
        }

        for record in records {
            record.isActive = (record.id == fallbackRecord.id)
            record.updatedAt = .now
        }
        try context.save()
        return true
    }

    private func enrichVehicleRecordsIfNeeded(_ records: [VehicleRecord]) throws -> Bool {
        var hasChanges = false

        for record in records {
            guard needsCatalogEnrichment(record) else { continue }
            guard let reference = bestReferenceSpec(for: record) else { continue }

            if record.enginePowerHP == nil {
                record.enginePowerHP = reference.enginePowerHP
                hasChanges = true
            }
            if record.enginePowerKW == nil {
                record.enginePowerKW = reference.enginePowerKW
                hasChanges = true
            }
            if record.acMaxChargingKW == nil {
                record.acMaxChargingKW = reference.acMaxChargingKW
                hasChanges = true
            }
            if record.dcMaxChargingKW == nil {
                record.dcMaxChargingKW = reference.dcMaxChargingKW
                hasChanges = true
            }
            if record.batteryCapacityKWh <= 0 {
                record.batteryCapacityKWh = reference.batteryCapacityKWh
                hasChanges = true
            }
            if record.factoryConsumptionKWh100km == nil {
                record.factoryConsumptionKWh100km = reference.factoryConsumptionKWh100km
                hasChanges = true
            }
            if record.silhouetteKey == nil {
                record.silhouetteKey = reference.silhouetteKey
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }

        return hasChanges
    }

    private func needsCatalogEnrichment(_ vehicle: VehicleRecord) -> Bool {
        vehicle.factoryConsumptionKWh100km == nil ||
        vehicle.enginePowerHP == nil ||
        vehicle.enginePowerKW == nil ||
        vehicle.acMaxChargingKW == nil ||
        vehicle.dcMaxChargingKW == nil ||
        vehicle.silhouetteKey == nil ||
        vehicle.batteryCapacityKWh <= 0
    }

    private func bestReferenceSpec(for vehicle: VehicleRecord) -> ReferenceVehicleSpec? {
        if let exact = vehicleCatalog.find(brand: vehicle.brand, model: vehicle.model, year: vehicle.year) {
            return exact
        }

        let candidates = vehicleCatalog.all().filter {
            $0.brand.caseInsensitiveCompare(vehicle.brand) == .orderedSame &&
            $0.model.caseInsensitiveCompare(vehicle.model) == .orderedSame
        }

        guard !candidates.isEmpty else { return nil }

        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs.year - vehicle.year)
            let rhsDistance = abs(rhs.year - vehicle.year)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.year > rhs.year
        }
    }
}
#endif
