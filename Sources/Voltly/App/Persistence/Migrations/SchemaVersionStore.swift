import Foundation

public protocol SchemaVersionStore {
    func currentSchemaVersion() -> Int?
    func setCurrentSchemaVersion(_ version: Int)
    func isFreshInstall() -> Bool

    func firstInstallDate() -> Date?
    func lastSuccessfulMigrationVersion() -> Int?
    func lastMigrationDate() -> Date?

    func markFreshInstall(defaultSchemaVersion: Int, at date: Date)
    func recordSuccessfulMigration(to version: Int, at date: Date)
}

public struct SchemaVersionState: Codable, Equatable, Sendable {
    public var currentSchemaVersion: Int?
    public var firstInstallDate: Date?
    public var lastSuccessfulMigrationVersion: Int?
    public var lastMigrationDate: Date?

    public init(
        currentSchemaVersion: Int? = nil,
        firstInstallDate: Date? = nil,
        lastSuccessfulMigrationVersion: Int? = nil,
        lastMigrationDate: Date? = nil
    ) {
        self.currentSchemaVersion = currentSchemaVersion
        self.firstInstallDate = firstInstallDate
        self.lastSuccessfulMigrationVersion = lastSuccessfulMigrationVersion
        self.lastMigrationDate = lastMigrationDate
    }
}

public final class UserDefaultsSchemaVersionStore: SchemaVersionStore {
    private enum Keys {
        static let legacySchemaVersion = "persistence.local_schema.version"
        static let state = "persistence.local_schema.state.v1"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func currentSchemaVersion() -> Int? {
        readState().currentSchemaVersion
    }

    public func setCurrentSchemaVersion(_ version: Int) {
        mutateState { state in
            state.currentSchemaVersion = version
        }
    }

    public func isFreshInstall() -> Bool {
        currentSchemaVersion() == nil
    }

    public func firstInstallDate() -> Date? {
        readState().firstInstallDate
    }

    public func lastSuccessfulMigrationVersion() -> Int? {
        readState().lastSuccessfulMigrationVersion
    }

    public func lastMigrationDate() -> Date? {
        readState().lastMigrationDate
    }

    public func markFreshInstall(defaultSchemaVersion: Int, at date: Date) {
        mutateState { state in
            guard state.currentSchemaVersion == nil else { return }
            state.currentSchemaVersion = defaultSchemaVersion
            state.firstInstallDate = state.firstInstallDate ?? date
            state.lastSuccessfulMigrationVersion = defaultSchemaVersion
            state.lastMigrationDate = date
        }
    }

    public func recordSuccessfulMigration(to version: Int, at date: Date) {
        mutateState { state in
            state.currentSchemaVersion = version
            state.firstInstallDate = state.firstInstallDate ?? date
            state.lastSuccessfulMigrationVersion = version
            state.lastMigrationDate = date
        }
    }

    private func readState() -> SchemaVersionState {
        lock.lock()
        defer { lock.unlock() }

        if let data = defaults.data(forKey: Keys.state),
           let decoded = try? decoder.decode(SchemaVersionState.self, from: data) {
            return decoded
        }

        // Backward-compatible one-time bootstrap from legacy key.
        if let legacyValue = defaults.object(forKey: Keys.legacySchemaVersion) as? Int {
            let migrated = SchemaVersionState(currentSchemaVersion: legacyValue)
            persist(migrated)
            defaults.removeObject(forKey: Keys.legacySchemaVersion)
            return migrated
        }

        return SchemaVersionState()
    }

    private func mutateState(_ update: (inout SchemaVersionState) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var state: SchemaVersionState
        if let data = defaults.data(forKey: Keys.state),
           let decoded = try? decoder.decode(SchemaVersionState.self, from: data) {
            state = decoded
        } else if let legacyValue = defaults.object(forKey: Keys.legacySchemaVersion) as? Int {
            state = SchemaVersionState(currentSchemaVersion: legacyValue)
            defaults.removeObject(forKey: Keys.legacySchemaVersion)
        } else {
            state = SchemaVersionState()
        }

        update(&state)
        persist(state)
    }

    private func persist(_ state: SchemaVersionState) {
        do {
            let data = try encoder.encode(state)
            defaults.set(data, forKey: Keys.state)
        } catch {
            assertionFailure("SchemaVersionState encode edilemedi: \(error.localizedDescription)")
        }
    }
}
