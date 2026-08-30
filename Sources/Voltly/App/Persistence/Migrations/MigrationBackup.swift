import Foundation

public enum MigrationBackupResult: String, Codable, Equatable, Sendable {
    case success
    case failed
    case skipped
}

public struct MigrationBackupMetadata: Codable, Equatable, Sendable {
    public let backupID: String
    public let createdAt: Date
    public let backupVersion: Int
    public let targetSchemaVersion: Int
    public let migrationIdentifiers: [String]
    public let filePath: String

    public init(
        backupID: String,
        createdAt: Date,
        backupVersion: Int,
        targetSchemaVersion: Int,
        migrationIdentifiers: [String],
        filePath: String
    ) {
        self.backupID = backupID
        self.createdAt = createdAt
        self.backupVersion = backupVersion
        self.targetSchemaVersion = targetSchemaVersion
        self.migrationIdentifiers = migrationIdentifiers
        self.filePath = filePath
    }
}

public struct MigrationBackupState: Codable, Equatable, Sendable {
    public var lastBackupDate: Date?
    public var backupVersion: Int?
    public var backupResult: MigrationBackupResult?
    public var lastBackupMetadata: MigrationBackupMetadata?

    public init(
        lastBackupDate: Date? = nil,
        backupVersion: Int? = nil,
        backupResult: MigrationBackupResult? = nil,
        lastBackupMetadata: MigrationBackupMetadata? = nil
    ) {
        self.lastBackupDate = lastBackupDate
        self.backupVersion = backupVersion
        self.backupResult = backupResult
        self.lastBackupMetadata = lastBackupMetadata
    }
}

public enum MigrationBackupError: LocalizedError, Equatable {
    case backupDirectoryUnavailable(description: String)
    case snapshotSerializationFailed(description: String)
    case snapshotWriteFailed(path: String, description: String)

    public var errorDescription: String? {
        switch self {
        case .backupDirectoryUnavailable(let description):
            return "Migration yedek klasoru hazirlanamadi: \(description)"
        case .snapshotSerializationFailed(let description):
            return "Migration snapshot verisi olusturulamadi: \(description)"
        case .snapshotWriteFailed(let path, let description):
            return "Migration snapshot dosyasi yazilamadi (\(path)): \(description)"
        }
    }
}

public enum MigrationBackup {
    public protocol BackupService {
        func createSnapshot(
            plan: [any Migration],
            fromVersion: Int,
            targetVersion: Int,
            context: MigrationContext
        ) throws -> MigrationBackupMetadata

        func recordResult(
            _ result: MigrationBackupResult,
            metadata: MigrationBackupMetadata?
        )

        func state() -> MigrationBackupState
        func lastBackupDate() -> Date?
        func backupVersion() -> Int?
        func backupResult() -> MigrationBackupResult?
    }
}

public extension MigrationBackup.BackupService {
    func lastBackupDate() -> Date? {
        state().lastBackupDate
    }

    func backupVersion() -> Int? {
        state().backupVersion
    }

    func backupResult() -> MigrationBackupResult? {
        state().backupResult
    }
}

public final class LocalBackupManager: MigrationBackup.BackupService {
    private enum Keys {
        static let state = "migration.backup.state.v1"
    }

    private enum Constants {
        static let backupDirectoryName = "VoltlyMigrationBackups"
        static let maxSnapshotCount = 8
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let now: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.now = now
    }

    public func createSnapshot(
        plan: [any Migration],
        fromVersion: Int,
        targetVersion: Int,
        context: MigrationContext
    ) throws -> MigrationBackupMetadata {
        let createdAt = now()
        let backupID = makeBackupIdentifier(
            fromVersion: fromVersion,
            targetVersion: targetVersion,
            createdAt: createdAt
        )
        let directory = try resolveBackupDirectory()
        let fileURL = directory.appendingPathComponent("\(backupID).json", isDirectory: false)

        let payload = makeSnapshotPayload(
            plan: plan,
            fromVersion: fromVersion,
            targetVersion: targetVersion,
            context: context,
            backupID: backupID,
            createdAt: createdAt
        )

        let data: Data
        do {
            data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.sortedKeys]
            )
        } catch {
            throw MigrationBackupError.snapshotSerializationFailed(
                description: error.localizedDescription
            )
        }

        do {
            try data.write(to: fileURL, options: [.atomic])
            try pruneOldSnapshots(in: directory)
        } catch {
            throw MigrationBackupError.snapshotWriteFailed(
                path: fileURL.path,
                description: error.localizedDescription
            )
        }

        return MigrationBackupMetadata(
            backupID: backupID,
            createdAt: createdAt,
            backupVersion: fromVersion,
            targetSchemaVersion: targetVersion,
            migrationIdentifiers: plan.map(\.id),
            filePath: fileURL.path
        )
    }

    public func recordResult(
        _ result: MigrationBackupResult,
        metadata: MigrationBackupMetadata?
    ) {
        mutateState { state in
            state.backupResult = result
            if let metadata {
                state.lastBackupMetadata = metadata
                state.lastBackupDate = metadata.createdAt
                state.backupVersion = metadata.backupVersion
            } else if result == .failed {
                state.lastBackupDate = now()
            }
        }
    }

    public func state() -> MigrationBackupState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: Keys.state),
              let decoded = try? decoder.decode(MigrationBackupState.self, from: data) else {
            return MigrationBackupState()
        }
        return decoded
    }

    private func resolveBackupDirectory() throws -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let backupDirectory = baseDirectory.appendingPathComponent(Constants.backupDirectoryName, isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
            return backupDirectory
        } catch {
            throw MigrationBackupError.backupDirectoryUnavailable(
                description: error.localizedDescription
            )
        }
    }

    private func makeSnapshotPayload(
        plan: [any Migration],
        fromVersion: Int,
        targetVersion: Int,
        context: MigrationContext,
        backupID: String,
        createdAt: Date
    ) -> [String: Any] {
        let release = context.appVersionManager.currentReleaseVersion
        let isoDate = ISO8601DateFormatter().string(from: createdAt)

        let snapshotValues = context.userDefaults.dictionaryRepresentation()
            .filter { isSnapshotKeyIncluded($0.key) }
            .mapValues { makeJSONCompatible($0) ?? NSNull() }

        let planItems: [[String: Any]] = plan.map { migration in
            [
                "id": migration.id,
                "name": migration.name,
                "fromVersion": migration.fromVersion,
                "toVersion": migration.toVersion,
                "isRequired": migration.isRequired,
                "requiresBackup": migration.requiresBackup
            ]
        }

        return [
            "metadata": [
                "backupID": backupID,
                "createdAt": isoDate,
                "backupVersion": fromVersion,
                "targetSchemaVersion": targetVersion
            ],
            "app": [
                "version": release.appVersion,
                "build": release.buildNumber
            ],
            "migrationPlan": planItems,
            "snapshot": snapshotValues
        ]
    }

    private func makeBackupIdentifier(
        fromVersion: Int,
        targetVersion: Int,
        createdAt: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: createdAt)
        return "migration-backup-v\(fromVersion)-to-v\(targetVersion)-\(stamp)"
    }

    private func isSnapshotKeyIncluded(_ key: String) -> Bool {
        if key.hasPrefix("Apple") || key.hasPrefix("NS") {
            return false
        }

        let includedPrefixes = [
            "persistence.",
            "settings.",
            "feature.",
            "migration.",
            "add_charge.",
            "insights.",
            "goal.",
            "backup.",
            "app."
        ]

        return includedPrefixes.contains { key.hasPrefix($0) }
    }

    private func makeJSONCompatible(_ value: Any) -> Any? {
        switch value {
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let data as Data:
            return [
                "__type": "data",
                "base64": data.base64EncodedString()
            ]
        case let url as URL:
            return url.absoluteString
        case let array as [Any]:
            return array.compactMap { makeJSONCompatible($0) }
        case let dictionary as [String: Any]:
            return dictionary.reduce(into: [String: Any]()) { partial, item in
                partial[item.key] = makeJSONCompatible(item.value) ?? NSNull()
            }
        default:
            return String(describing: value)
        }
    }

    private func mutateState(_ block: (inout MigrationBackupState) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var current = MigrationBackupState()
        if let data = defaults.data(forKey: Keys.state),
           let decoded = try? decoder.decode(MigrationBackupState.self, from: data) {
            current = decoded
        }
        block(&current)

        if let data = try? encoder.encode(current) {
            defaults.set(data, forKey: Keys.state)
        }
    }

    private func pruneOldSnapshots(in directory: URL) throws {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let sorted = try urls.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }
        guard sorted.count > Constants.maxSnapshotCount else { return }
        for staleURL in sorted.dropFirst(Constants.maxSnapshotCount) {
            try? fileManager.removeItem(at: staleURL)
        }
    }
}
