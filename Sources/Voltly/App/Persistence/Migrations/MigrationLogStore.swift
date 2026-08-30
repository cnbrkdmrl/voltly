import Foundation

public struct MigrationStoredError: Codable, Equatable, Sendable {
    public let message: String
    public let createdAt: Date

    public init(message: String, createdAt: Date) {
        self.message = message
        self.createdAt = createdAt
    }
}

public struct MigrationLogEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let level: MigrationLogLevel
    public let message: String
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        level: MigrationLogLevel,
        message: String,
        metadata: [String: String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.level = level
        self.message = message
        self.metadata = metadata
    }
}

public enum MigrationHistoryStatus: String, Codable, Equatable, Sendable {
    case success
    case failed
    case skipped
}

public struct MigrationHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let migrationID: String
    public let migrationName: String
    public let fromVersion: Int
    public let toVersion: Int
    public let durationMs: Int
    public let status: MigrationHistoryStatus
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        migrationID: String,
        migrationName: String,
        fromVersion: Int,
        toVersion: Int,
        durationMs: Int,
        status: MigrationHistoryStatus,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.migrationID = migrationID
        self.migrationName = migrationName
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.durationMs = durationMs
        self.status = status
        self.errorMessage = errorMessage
    }
}

public protocol MigrationLogStore {
    func appendLog(_ entry: MigrationLogEntry)
    func appendHistory(_ entry: MigrationHistoryEntry)

    func logs(limit: Int?) -> [MigrationLogEntry]
    func history(limit: Int?) -> [MigrationHistoryEntry]

    func setLastError(_ error: MigrationStoredError?)
    func lastError() -> MigrationStoredError?

    func clearAll()
}

private struct MigrationLogStoreState: Codable, Equatable, Sendable {
    var logs: [MigrationLogEntry]
    var history: [MigrationHistoryEntry]
    var lastError: MigrationStoredError?

    init(
        logs: [MigrationLogEntry] = [],
        history: [MigrationHistoryEntry] = [],
        lastError: MigrationStoredError? = nil
    ) {
        self.logs = logs
        self.history = history
        self.lastError = lastError
    }
}

public final class UserDefaultsMigrationLogStore: MigrationLogStore {
    private enum Keys {
        static let state = "migration.debug.log_store.state.v1"
    }

    private enum Limits {
        static let maxLogs = 500
        static let maxHistory = 200
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func appendLog(_ entry: MigrationLogEntry) {
        mutateState { state in
            state.logs.insert(entry, at: 0)
            if state.logs.count > Limits.maxLogs {
                state.logs = Array(state.logs.prefix(Limits.maxLogs))
            }
        }
    }

    public func appendHistory(_ entry: MigrationHistoryEntry) {
        mutateState { state in
            state.history.insert(entry, at: 0)
            if state.history.count > Limits.maxHistory {
                state.history = Array(state.history.prefix(Limits.maxHistory))
            }
        }
    }

    public func logs(limit: Int? = nil) -> [MigrationLogEntry] {
        let all = readState().logs
        guard let limit else { return all }
        return Array(all.prefix(max(0, limit)))
    }

    public func history(limit: Int? = nil) -> [MigrationHistoryEntry] {
        let all = readState().history
        guard let limit else { return all }
        return Array(all.prefix(max(0, limit)))
    }

    public func setLastError(_ error: MigrationStoredError?) {
        mutateState { state in
            state.lastError = error
        }
    }

    public func lastError() -> MigrationStoredError? {
        readState().lastError
    }

    public func clearAll() {
        mutateState { state in
            state = MigrationLogStoreState()
        }
    }

    private func readState() -> MigrationLogStoreState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: Keys.state),
              let decoded = try? decoder.decode(MigrationLogStoreState.self, from: data) else {
            return MigrationLogStoreState()
        }
        return decoded
    }

    private func mutateState(_ mutate: (inout MigrationLogStoreState) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var state = MigrationLogStoreState()
        if let data = defaults.data(forKey: Keys.state),
           let decoded = try? decoder.decode(MigrationLogStoreState.self, from: data) {
            state = decoded
        }

        mutate(&state)

        if let data = try? encoder.encode(state) {
            defaults.set(data, forKey: Keys.state)
        }
    }
}

public final class MigrationLogStoreLogger: MigrationLogging {
    private let store: any MigrationLogStore
    private let now: () -> Date

    public init(
        store: any MigrationLogStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
    }

    public func log(
        _ level: MigrationLogLevel,
        message: String,
        metadata: [String: String]
    ) {
        store.appendLog(
            MigrationLogEntry(
                createdAt: now(),
                level: level,
                message: message,
                metadata: metadata
            )
        )
    }
}

public final class CompositeMigrationLogger: MigrationLogging {
    private let loggers: [any MigrationLogging]

    public init(loggers: [any MigrationLogging]) {
        self.loggers = loggers
    }

    public func log(
        _ level: MigrationLogLevel,
        message: String,
        metadata: [String: String]
    ) {
        for logger in loggers {
            logger.log(level, message: message, metadata: metadata)
        }
    }
}

extension MigrationLogLevel: Codable {}
