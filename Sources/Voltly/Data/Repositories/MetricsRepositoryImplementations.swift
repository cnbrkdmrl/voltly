import Foundation

public final class InMemoryConsumptionBlockRepository: ConsumptionBlockRepository {
    private var blocksByVehicle: [UUID: [ConsumptionBlock]] = [:]

    public init() {}

    public func fetchActive(vehicleID: UUID) throws -> [ConsumptionBlock] {
        blocksByVehicle[vehicleID, default: []]
            .filter(\.isActive)
            .sorted { $0.endDate < $1.endDate }
    }

    public func replaceActive(vehicleID: UUID, blocks: [ConsumptionBlock]) throws {
        blocksByVehicle[vehicleID] = blocks.sorted { $0.endDate < $1.endDate }
    }

    public func markDirty(vehicleID: UUID, touching recordIDs: Set<UUID>) throws {
        guard !recordIDs.isEmpty else { return }
        let updated = blocksByVehicle[vehicleID, default: []].map { block in
            let touches = recordIDs.contains(block.endRecordID) || (block.startRecordID.map(recordIDs.contains) ?? false)
            guard touches else { return block }
            return ConsumptionBlock(
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
                confidenceType: block.confidenceType,
                calculationBasis: block.calculationBasis,
                isActive: block.isActive,
                isDirty: true,
                version: block.version + 1,
                updatedAt: .now,
                startDate: block.startDate,
                endDate: block.endDate
            )
        }
        blocksByVehicle[vehicleID] = updated
    }
}

public final class InMemoryVehicleMetricSnapshotRepository: VehicleMetricSnapshotRepository {
    private var snapshotsByVehicle: [UUID: [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot]] = [:]

    public init() {}

    public func fetchAll(vehicleID: UUID) throws -> [VehicleMetricSnapshot] {
        Array(snapshotsByVehicle[vehicleID, default: [:]].values)
            .sorted { $0.period.rawValue < $1.period.rawValue }
    }

    public func fetch(vehicleID: UUID, period: VehicleMetricSnapshotPeriod) throws -> VehicleMetricSnapshot? {
        snapshotsByVehicle[vehicleID]?[period]
    }

    public func replace(vehicleID: UUID, snapshots: [VehicleMetricSnapshot]) throws {
        snapshotsByVehicle[vehicleID] = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.period, $0) })
    }
}

public protocol DashboardCacheService {
    func cache(update: ChargeMetricsRealtimeUpdate) throws
    func fetch(vehicleID: UUID) throws -> ChargeMetricsRealtimeUpdate?
    func invalidate(vehicleID: UUID) throws
}

public final class InMemoryDashboardCacheService: DashboardCacheService {
    private var updates: [UUID: ChargeMetricsRealtimeUpdate] = [:]

    public init() {}

    public func cache(update: ChargeMetricsRealtimeUpdate) throws {
        updates[update.vehicleID] = update
    }

    public func fetch(vehicleID: UUID) throws -> ChargeMetricsRealtimeUpdate? {
        updates[vehicleID]
    }

    public func invalidate(vehicleID: UUID) throws {
        updates.removeValue(forKey: vehicleID)
    }
}

public final class UserDefaultsConsumptionBlockRepository: ConsumptionBlockRepository {
    private enum Keys {
        static let prefix = "voltly.metrics.blocks"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func fetchActive(vehicleID: UUID) throws -> [ConsumptionBlock] {
        try load(vehicleID: vehicleID)
            .filter(\.isActive)
            .sorted { $0.endDate < $1.endDate }
    }

    public func replaceActive(vehicleID: UUID, blocks: [ConsumptionBlock]) throws {
        try save(blocks.sorted { $0.endDate < $1.endDate }, vehicleID: vehicleID)
    }

    public func markDirty(vehicleID: UUID, touching recordIDs: Set<UUID>) throws {
        guard !recordIDs.isEmpty else { return }
        let blocks = try load(vehicleID: vehicleID).map { block in
            let touches = recordIDs.contains(block.endRecordID) || (block.startRecordID.map(recordIDs.contains) ?? false)
            guard touches else { return block }
            return ConsumptionBlock(
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
                confidenceType: block.confidenceType,
                calculationBasis: block.calculationBasis,
                isActive: block.isActive,
                isDirty: true,
                version: block.version + 1,
                updatedAt: .now,
                startDate: block.startDate,
                endDate: block.endDate
            )
        }
        try save(blocks, vehicleID: vehicleID)
    }

    private func load(vehicleID: UUID) throws -> [ConsumptionBlock] {
        guard let data = defaults.data(forKey: key(for: vehicleID)) else { return [] }
        return try decoder.decode([ConsumptionBlock].self, from: data)
    }

    private func save(_ blocks: [ConsumptionBlock], vehicleID: UUID) throws {
        defaults.set(try encoder.encode(blocks), forKey: key(for: vehicleID))
    }

    private func key(for vehicleID: UUID) -> String {
        "\(Keys.prefix).\(vehicleID.uuidString)"
    }
}

public final class UserDefaultsVehicleMetricSnapshotRepository: VehicleMetricSnapshotRepository {
    private enum Keys {
        static let prefix = "voltly.metrics.snapshots"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func fetchAll(vehicleID: UUID) throws -> [VehicleMetricSnapshot] {
        let dictionary = try load(vehicleID: vehicleID)
        return Array(dictionary.values).sorted { $0.period.rawValue < $1.period.rawValue }
    }

    public func fetch(vehicleID: UUID, period: VehicleMetricSnapshotPeriod) throws -> VehicleMetricSnapshot? {
        try load(vehicleID: vehicleID)[period]
    }

    public func replace(vehicleID: UUID, snapshots: [VehicleMetricSnapshot]) throws {
        let dictionary = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.period, $0) })
        defaults.set(try encoder.encode(dictionary), forKey: key(for: vehicleID))
    }

    private func load(vehicleID: UUID) throws -> [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot] {
        guard let data = defaults.data(forKey: key(for: vehicleID)) else { return [:] }
        return try decoder.decode([VehicleMetricSnapshotPeriod: VehicleMetricSnapshot].self, from: data)
    }

    private func key(for vehicleID: UUID) -> String {
        "\(Keys.prefix).\(vehicleID.uuidString)"
    }
}

public final class UserDefaultsDashboardCacheService: DashboardCacheService {
    private enum Keys {
        static let prefix = "voltly.metrics.dashboard-cache"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func cache(update: ChargeMetricsRealtimeUpdate) throws {
        defaults.set(try encoder.encode(update), forKey: key(for: update.vehicleID))
    }

    public func fetch(vehicleID: UUID) throws -> ChargeMetricsRealtimeUpdate? {
        guard let data = defaults.data(forKey: key(for: vehicleID)) else { return nil }
        return try decoder.decode(ChargeMetricsRealtimeUpdate.self, from: data)
    }

    public func invalidate(vehicleID: UUID) throws {
        defaults.removeObject(forKey: key(for: vehicleID))
    }

    private func key(for vehicleID: UUID) -> String {
        "\(Keys.prefix).\(vehicleID.uuidString)"
    }
}
