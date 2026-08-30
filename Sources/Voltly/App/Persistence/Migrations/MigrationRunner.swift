import Foundation

public enum MigrationLogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public protocol MigrationLogging {
    func log(
        _ level: MigrationLogLevel,
        message: String,
        metadata: [String: String]
    )
}

/// Example format:
/// [MIGRATION][INFO][2026-03-23T14:40:05Z] message | key=value key2=value2
public struct DefaultMigrationLogger: MigrationLogging {
    private let formatter: ISO8601DateFormatter

    public init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    public func log(
        _ level: MigrationLogLevel,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let timestamp = formatter.string(from: Date())
        #if DEBUG
        let metadataText = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        if metadataText.isEmpty {
            print("[MIGRATION][\(level.rawValue)][\(timestamp)] \(message)")
        } else {
            print("[MIGRATION][\(level.rawValue)][\(timestamp)] \(message) | \(metadataText)")
        }
        #else
        print("[MIGRATION][\(level.rawValue)] \(message)")
        #endif
    }
}

public enum MigrationRunStatus: String, Equatable, Sendable {
    case applied
    case skipped
}

public struct MigrationExecutionTrace: Equatable, Sendable {
    public let id: String
    public let name: String
    public let fromVersion: Int
    public let toVersion: Int
    public let isRequired: Bool
    public let status: MigrationRunStatus
    public let durationMs: Int

    public init(
        id: String,
        name: String,
        fromVersion: Int,
        toVersion: Int,
        isRequired: Bool,
        status: MigrationRunStatus,
        durationMs: Int
    ) {
        self.id = id
        self.name = name
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.isRequired = isRequired
        self.status = status
        self.durationMs = durationMs
    }
}

public enum MigrationRunnerError: LocalizedError, Equatable {
    case invalidTargetVersion(Int)
    case targetOlderThanCurrent(current: Int, target: Int)
    case registryValidationFailed(MigrationRegistryValidationError)
    case backupFailed(required: Bool, underlyingDescription: String)
    case executionFailed(
        migrationID: String,
        migrationName: String,
        underlyingDescription: String
    )

    public var errorDescription: String? {
        switch self {
        case .invalidTargetVersion(let value):
            return "Hedef schema surumu gecersiz: \(value)."
        case .targetOlderThanCurrent(let current, let target):
            return "Hedef schema surumu mevcut surumden kucuk olamaz. Mevcut: \(current), hedef: \(target)."
        case .registryValidationFailed(let error):
            return error.localizedDescription
        case .backupFailed(let required, let underlyingDescription):
            if required {
                return "Migration oncesi zorunlu yedek alinamadi: \(underlyingDescription)"
            }
            return "Migration oncesi yedekleme basarisiz oldu: \(underlyingDescription)"
        case .executionFailed(let migrationID, let migrationName, let underlyingDescription):
            return "Migration calismasi basarisiz (\(migrationID) - \(migrationName)): \(underlyingDescription)"
        }
    }
}

public struct MigrationRunReport: Equatable, Sendable {
    public let previousSchemaVersion: Int?
    public let targetSchemaVersion: Int
    public let appliedMigrationIdentifiers: [String]
    public let initializedOnFirstInstall: Bool
    public let previousAppVersion: AppReleaseVersion?
    public let currentAppVersion: AppReleaseVersion
    public let warnings: [MigrationRegistryWarning]
    public let traces: [MigrationExecutionTrace]
    public let backupMetadata: MigrationBackupMetadata?
    public let backupResult: MigrationBackupResult?

    public init(
        previousSchemaVersion: Int?,
        targetSchemaVersion: Int,
        appliedMigrationIdentifiers: [String],
        initializedOnFirstInstall: Bool,
        previousAppVersion: AppReleaseVersion?,
        currentAppVersion: AppReleaseVersion,
        warnings: [MigrationRegistryWarning],
        traces: [MigrationExecutionTrace],
        backupMetadata: MigrationBackupMetadata? = nil,
        backupResult: MigrationBackupResult? = nil
    ) {
        self.previousSchemaVersion = previousSchemaVersion
        self.targetSchemaVersion = targetSchemaVersion
        self.appliedMigrationIdentifiers = appliedMigrationIdentifiers
        self.initializedOnFirstInstall = initializedOnFirstInstall
        self.previousAppVersion = previousAppVersion
        self.currentAppVersion = currentAppVersion
        self.warnings = warnings
        self.traces = traces
        self.backupMetadata = backupMetadata
        self.backupResult = backupResult
    }
}

public final class MigrationRunner {
    private let schemaVersionStore: any SchemaVersionStore
    private let migrationRegistry: MigrationRegistry
    private let migrationContext: MigrationContext
    private let appVersionManager: AppVersionManager
    private let backupService: any MigrationBackup.BackupService
    private let migrationLogStore: (any MigrationLogStore)?
    private let logger: any MigrationLogging
    private let now: () -> Date

    public init(
        schemaVersionStore: any SchemaVersionStore,
        migrationRegistry: MigrationRegistry,
        migrationContext: MigrationContext,
        appVersionManager: AppVersionManager,
        backupService: any MigrationBackup.BackupService,
        migrationLogStore: (any MigrationLogStore)? = nil,
        logger: any MigrationLogging = DefaultMigrationLogger(),
        now: @escaping () -> Date = Date.init
    ) {
        self.schemaVersionStore = schemaVersionStore
        self.migrationRegistry = migrationRegistry
        self.migrationContext = migrationContext
        self.appVersionManager = appVersionManager
        self.backupService = backupService
        self.migrationLogStore = migrationLogStore
        self.logger = logger
        self.now = now
    }

    @discardableResult
    public func runMigrationsIfNeeded(targetSchemaVersion: Int) throws -> MigrationRunReport {
        guard targetSchemaVersion > 0 else {
            throw MigrationRunnerError.invalidTargetVersion(targetSchemaVersion)
        }

        let previousSchemaVersion = schemaVersionStore.currentSchemaVersion()
        let previousAppVersion = appVersionManager.lastLaunchedReleaseVersion
        let currentAppVersion = appVersionManager.currentReleaseVersion

        migrationLogStore?.setLastError(nil)

        logger.log(
            .info,
            message: "Migration kontrolu basladi.",
            metadata: [
                "currentSchema": previousSchemaVersion.map(String.init) ?? "nil",
                "targetSchema": String(targetSchemaVersion),
                "appVersion": currentAppVersion.appVersion,
                "build": currentAppVersion.buildNumber
            ]
        )

        if previousSchemaVersion == nil {
            // First install: no migration chain required, just initialize schema marker.
            schemaVersionStore.markFreshInstall(
                defaultSchemaVersion: targetSchemaVersion,
                at: now()
            )
            appVersionManager.markCurrentReleaseAsLaunched()
            logger.log(
                .info,
                message: "Ilk kurulum schema surumu baslatildi.",
                metadata: ["schemaVersion": String(targetSchemaVersion)]
            )
            return MigrationRunReport(
                previousSchemaVersion: nil,
                targetSchemaVersion: targetSchemaVersion,
                appliedMigrationIdentifiers: [],
                initializedOnFirstInstall: true,
                previousAppVersion: previousAppVersion,
                currentAppVersion: currentAppVersion,
                warnings: [],
                traces: [],
                backupMetadata: nil,
                backupResult: nil
            )
        }

        guard let currentSchemaVersion = previousSchemaVersion else {
            throw MigrationRunnerError.invalidTargetVersion(targetSchemaVersion)
        }

        guard currentSchemaVersion <= targetSchemaVersion else {
            throw MigrationRunnerError.targetOlderThanCurrent(
                current: currentSchemaVersion,
                target: targetSchemaVersion
            )
        }

        let validationReport: MigrationValidationReport
        do {
            validationReport = try migrationRegistry.validate(
                from: currentSchemaVersion,
                to: targetSchemaVersion
            )
        } catch let validationError as MigrationRegistryValidationError {
            logger.log(
                .error,
                message: "Migration dogrulamasi basarisiz.",
                metadata: ["reason": validationError.localizedDescription]
            )
            migrationLogStore?.setLastError(
                MigrationStoredError(
                    message: validationError.localizedDescription,
                    createdAt: now()
                )
            )
            throw MigrationRunnerError.registryValidationFailed(validationError)
        }

        for warning in validationReport.warnings {
            logger.log(
                .warning,
                message: warning.message,
                metadata: ["code": warning.code]
            )
        }

        let plan: [any Migration]
        do {
            plan = try migrationRegistry.requiredMigrations(
                from: currentSchemaVersion,
                to: targetSchemaVersion
            )
        } catch let validationError as MigrationRegistryValidationError {
            logger.log(
                .error,
                message: "Migration plani olusturulamadi.",
                metadata: ["reason": validationError.localizedDescription]
            )
            migrationLogStore?.setLastError(
                MigrationStoredError(
                    message: validationError.localizedDescription,
                    createdAt: now()
                )
            )
            throw MigrationRunnerError.registryValidationFailed(validationError)
        }

        if plan.isEmpty {
            appVersionManager.markCurrentReleaseAsLaunched()
            logger.log(
                .info,
                message: "Migration gerekmiyor, schema guncel.",
                metadata: ["schemaVersion": String(targetSchemaVersion)]
            )
            return MigrationRunReport(
                previousSchemaVersion: currentSchemaVersion,
                targetSchemaVersion: targetSchemaVersion,
                appliedMigrationIdentifiers: [],
                initializedOnFirstInstall: false,
                previousAppVersion: previousAppVersion,
                currentAppVersion: currentAppVersion,
                warnings: validationReport.warnings,
                traces: [],
                backupMetadata: nil,
                backupResult: nil
            )
        }

        var activeSchemaVersion = currentSchemaVersion
        var traces: [MigrationExecutionTrace] = []
        let isBackupRequired = plan.contains(where: \.requiresBackup)
        var backupMetadata: MigrationBackupMetadata?
        var backupResult: MigrationBackupResult = .skipped

        do {
            let metadata = try backupService.createSnapshot(
                plan: plan,
                fromVersion: currentSchemaVersion,
                targetVersion: targetSchemaVersion,
                context: migrationContext
            )
            backupMetadata = metadata
            backupResult = .success
            backupService.recordResult(.success, metadata: metadata)
            logger.log(
                .info,
                message: "Migration oncesi snapshot alindi.",
                metadata: [
                    "backupID": metadata.backupID,
                    "backupVersion": String(metadata.backupVersion),
                    "targetSchema": String(metadata.targetSchemaVersion),
                    "required": isBackupRequired ? "true" : "false"
                ]
            )
        } catch {
            backupResult = .failed
            backupService.recordResult(.failed, metadata: nil)
            logger.log(
                .error,
                message: "Migration oncesi snapshot alinamadi.",
                metadata: [
                    "required": isBackupRequired ? "true" : "false",
                    "reason": error.localizedDescription
                ]
            )
            if isBackupRequired {
                migrationLogStore?.setLastError(
                    MigrationStoredError(
                        message: error.localizedDescription,
                        createdAt: now()
                    )
                )
                throw MigrationRunnerError.backupFailed(
                    required: true,
                    underlyingDescription: error.localizedDescription
                )
            }
            logger.log(
                .warning,
                message: "Backup basarisiz olsa da migration devam ediyor.",
                metadata: ["policy": "non_required_backup"]
            )
        }

        for migration in plan {
            // Defensive guard: execution plan must always be continuous.
            guard migration.fromVersion == activeSchemaVersion else {
                let chainError = MigrationRegistryValidationError.missingStep(
                    fromVersion: activeSchemaVersion,
                    targetVersion: targetSchemaVersion
                )
                migrationLogStore?.setLastError(
                    MigrationStoredError(
                        message: chainError.localizedDescription,
                        createdAt: now()
                    )
                )
                throw MigrationRunnerError.registryValidationFailed(chainError)
            }

            logger.log(
                .info,
                message: "Migration calistiriliyor.",
                metadata: [
                    "id": migration.id,
                    "name": migration.name,
                    "from": String(migration.fromVersion),
                    "to": String(migration.toVersion),
                    "required": migration.isRequired ? "true" : "false"
                ]
            )

            let startedAt = Date()
            do {
                try migration.run(context: migrationContext)
            } catch {
                let durationMs = Self.durationMs(since: startedAt)
                migrationLogStore?.appendHistory(
                    MigrationHistoryEntry(
                        createdAt: now(),
                        migrationID: migration.id,
                        migrationName: migration.name,
                        fromVersion: migration.fromVersion,
                        toVersion: migration.toVersion,
                        durationMs: durationMs,
                        status: .failed,
                        errorMessage: error.localizedDescription
                    )
                )
                migrationLogStore?.setLastError(
                    MigrationStoredError(
                        message: error.localizedDescription,
                        createdAt: now()
                    )
                )
                logger.log(
                    .error,
                    message: "Migration basarisiz oldu.",
                    metadata: [
                        "id": migration.id,
                        "name": migration.name,
                        "durationMs": String(durationMs),
                        "reason": error.localizedDescription
                    ]
                )
                throw MigrationRunnerError.executionFailed(
                    migrationID: migration.id,
                    migrationName: migration.name,
                    underlyingDescription: error.localizedDescription
                )
            }

            // Schema marker is advanced only after a successful migration run.
            schemaVersionStore.recordSuccessfulMigration(to: migration.toVersion, at: now())
            activeSchemaVersion = migration.toVersion
            let durationMs = Self.durationMs(since: startedAt)

            traces.append(
                MigrationExecutionTrace(
                    id: migration.id,
                    name: migration.name,
                    fromVersion: migration.fromVersion,
                    toVersion: migration.toVersion,
                    isRequired: migration.isRequired,
                    status: .applied,
                    durationMs: durationMs
                )
            )
            migrationLogStore?.appendHistory(
                MigrationHistoryEntry(
                    createdAt: now(),
                    migrationID: migration.id,
                    migrationName: migration.name,
                    fromVersion: migration.fromVersion,
                    toVersion: migration.toVersion,
                    durationMs: durationMs,
                    status: .success,
                    errorMessage: nil
                )
            )

            logger.log(
                .info,
                message: "Migration tamamlandi.",
                metadata: [
                    "id": migration.id,
                    "to": String(migration.toVersion),
                    "durationMs": String(durationMs)
                ]
            )
        }

        appVersionManager.markCurrentReleaseAsLaunched()

        let appliedIDs = traces
            .filter { $0.status == .applied }
            .map(\.id)

        logger.log(
            .info,
            message: "Migration zinciri tamamlandi.",
            metadata: [
                "appliedCount": String(appliedIDs.count),
                "finalSchema": String(targetSchemaVersion)
            ]
        )

        return MigrationRunReport(
            previousSchemaVersion: currentSchemaVersion,
            targetSchemaVersion: targetSchemaVersion,
            appliedMigrationIdentifiers: appliedIDs,
            initializedOnFirstInstall: false,
            previousAppVersion: previousAppVersion,
            currentAppVersion: currentAppVersion,
            warnings: validationReport.warnings,
            traces: traces,
            backupMetadata: backupMetadata,
            backupResult: backupResult
        )
    }

    private static func durationMs(since startedAt: Date) -> Int {
        let seconds = Date().timeIntervalSince(startedAt)
        return Int((seconds * 1_000).rounded())
    }
}
