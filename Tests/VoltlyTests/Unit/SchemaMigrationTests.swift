#if canImport(XCTest)
import XCTest
@testable import Voltly

final class SchemaMigrationTests: XCTestCase {
    func testFirstInstallInitializesSchemaVersionWithoutRunningMigrations() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(
                    id: "migration.v1_to_v2",
                    name: "v1 -> v2",
                    fromVersion: 1,
                    toVersion: 2
                )
            ]
        )
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults)
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 2)

        XCTAssertTrue(report.initializedOnFirstInstall)
        XCTAssertEqual(report.appliedMigrationIdentifiers, [])
        XCTAssertEqual(schemaStore.currentSchemaVersion(), 2)
        XCTAssertFalse(schemaStore.isFreshInstall())
        XCTAssertEqual(schemaStore.lastSuccessfulMigrationVersion(), 2)
        XCTAssertNotNil(schemaStore.firstInstallDate())
        XCTAssertNotNil(schemaStore.lastMigrationDate())
        XCTAssertEqual(
            appVersionManager.lastLaunchedReleaseVersion,
            appVersionManager.currentReleaseVersion
        )
    }

    func testRunnerAppliesSequentialMigrationsInOrder() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.setCurrentSchemaVersion(1)
        let logStore = UserDefaultsMigrationLogStore(defaults: defaults)

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let recorder = MigrationRecorder()
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(
                    id: "migration.v1_to_v2",
                    name: "v1 -> v2",
                    fromVersion: 1,
                    toVersion: 2,
                    recorder: recorder
                ),
                RecordingMigration(
                    id: "migration.v2_to_v3",
                    name: "v2 -> v3",
                    fromVersion: 2,
                    toVersion: 3,
                    recorder: recorder
                )
            ]
        )
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults),
            migrationLogStore: logStore
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)

        XCTAssertFalse(report.initializedOnFirstInstall)
        XCTAssertEqual(
            report.appliedMigrationIdentifiers,
            ["migration.v1_to_v2", "migration.v2_to_v3"]
        )
        XCTAssertEqual(recorder.appliedIdentifiers, report.appliedMigrationIdentifiers)
        XCTAssertEqual(schemaStore.currentSchemaVersion(), 3)
        XCTAssertEqual(schemaStore.lastSuccessfulMigrationVersion(), 3)
        XCTAssertNotNil(schemaStore.lastMigrationDate())
        XCTAssertEqual(logStore.history(limit: nil).count, 2)
        XCTAssertNil(logStore.lastError())
    }

    func testRunnerThrowsWhenMigrationChainIsMissing() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.setCurrentSchemaVersion(1)

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(
                    id: "migration.v1_to_v2",
                    name: "v1 -> v2",
                    fromVersion: 1,
                    toVersion: 2
                )
            ]
        )
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults)
        )

        XCTAssertThrowsError(try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)) { error in
            XCTAssertEqual(
                error as? MigrationRunnerError,
                .registryValidationFailed(.missingStep(fromVersion: 2, targetVersion: 3))
            )
        }
    }

    func testBuiltInMigrationsUpgradeLegacyChargeDraftAndBootstrapFeatureToggles() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.setCurrentSchemaVersion(LocalSchemaVersion.v1.rawValue)

        let draftKey = "add_charge.draft"
        let legacyDraft: [String: Any] = [
            "chargeType": "FAST_DC",
            "station": "ZES",
            "totalPrice": "500"
        ]
        let legacyDraftData = try JSONSerialization.data(withJSONObject: legacyDraft, options: [])
        defaults.set(legacyDraftData, forKey: draftKey)
        defaults.set(["insights.micro.enabled": false], forKey: "settings.features.toggles.v1")

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let registry = try MigrationRegistry.makeDefault()
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults)
        )

        _ = try runner.runMigrationsIfNeeded(
            targetSchemaVersion: LocalSchemaVersion.current.rawValue
        )

        let migratedDraftData = try XCTUnwrap(defaults.data(forKey: draftKey))
        let migratedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: migratedDraftData) as? [String: Any]
        )
        XCTAssertEqual(migratedObject["notes"] as? String, "")
        XCTAssertEqual(migratedObject["stationName"] as? String, "ZES")
        XCTAssertEqual(migratedObject["stationBrand"] as? String, "ZES")
        XCTAssertEqual(migratedObject["chargeMethodRaw"] as? String, ChargeMethod.home.rawValue)
        XCTAssertNil(migratedObject["chargeType"])

        let toggles = try XCTUnwrap(defaults.dictionary(forKey: "settings.features.toggles.v1"))
        XCTAssertEqual(toggles["insights.micro.enabled"] as? Bool, false)
        XCTAssertEqual(toggles["insights.trend_break.enabled"] as? Bool, true)
        XCTAssertEqual(toggles["charge.smart_repeat.enabled"] as? Bool, true)
        XCTAssertEqual(toggles[AppFeature.advancedInsights.key] as? Bool, false)
        XCTAssertEqual(toggles[AppFeature.smartRecommendations.key] as? Bool, true)
        XCTAssertEqual(toggles[AppFeature.savingsBankV2.key] as? Bool, false)
        XCTAssertEqual(toggles[AppFeature.exportPDF.key] as? Bool, false)
        XCTAssertEqual(toggles[AppFeature.betaDashboardCards.key] as? Bool, false)
    }

    func testStorePersistsInstallAndMigrationMetadata() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsSchemaVersionStore(defaults: defaults)
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        let migrationDate = Date(timeIntervalSince1970: 1_700_000_111)

        XCTAssertTrue(store.isFreshInstall())
        XCTAssertNil(store.currentSchemaVersion())
        XCTAssertNil(store.firstInstallDate())
        XCTAssertNil(store.lastSuccessfulMigrationVersion())
        XCTAssertNil(store.lastMigrationDate())

        store.markFreshInstall(defaultSchemaVersion: 2, at: installDate)
        store.recordSuccessfulMigration(to: 3, at: migrationDate)

        XCTAssertFalse(store.isFreshInstall())
        XCTAssertEqual(store.currentSchemaVersion(), 3)
        XCTAssertEqual(store.firstInstallDate(), installDate)
        XCTAssertEqual(store.lastSuccessfulMigrationVersion(), 3)
        XCTAssertEqual(store.lastMigrationDate(), migrationDate)
    }

    func testRunnerRecordsDeterministicMigrationDatesViaClockInjection() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.markFreshInstall(
            defaultSchemaVersion: LocalSchemaVersion.v1.rawValue,
            at: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let expectedDate = Date(timeIntervalSince1970: 1_700_000_500)
        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let registry = try MigrationRegistry.makeDefault()
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults),
            now: { expectedDate }
        )

        _ = try runner.runMigrationsIfNeeded(targetSchemaVersion: LocalSchemaVersion.current.rawValue)

        XCTAssertEqual(schemaStore.currentSchemaVersion(), LocalSchemaVersion.current.rawValue)
        XCTAssertEqual(schemaStore.lastSuccessfulMigrationVersion(), LocalSchemaVersion.current.rawValue)
        XCTAssertEqual(schemaStore.lastMigrationDate(), expectedDate)
    }

    func testRegistryValidationFailsOnDuplicateID() throws {
        XCTAssertThrowsError(
            try MigrationRegistry(
                migrations: [
                    RecordingMigration(id: "duplicate", name: "A", fromVersion: 1, toVersion: 2),
                    RecordingMigration(id: "duplicate", name: "B", fromVersion: 2, toVersion: 3)
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? MigrationRegistryValidationError,
                .duplicateID("duplicate")
            )
        }
    }

    func testRegistryReturnsOrderingWarningWhenInputOrderIsNotAscending() throws {
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(id: "m2", name: "v2 -> v3", fromVersion: 2, toVersion: 3),
                RecordingMigration(id: "m1", name: "v1 -> v2", fromVersion: 1, toVersion: 2)
            ]
        )

        let report = try registry.validate(from: 1, to: 3)
        XCTAssertEqual(report.warnings.count, 1)
        XCTAssertEqual(report.warnings.first?.code, "ORDER_MISMATCH")
    }

    func testRunnerStopsWhenRequiredBackupFails() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.setCurrentSchemaVersion(1)
        let logStore = UserDefaultsMigrationLogStore(defaults: defaults)

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let recorder = MigrationRecorder()
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(
                    id: "migration.v1_to_v2",
                    name: "v1 -> v2",
                    fromVersion: 1,
                    toVersion: 2,
                    requiresBackup: true,
                    recorder: recorder
                )
            ]
        )
        let backupService = FailingBackupService()
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: backupService,
            migrationLogStore: logStore
        )

        XCTAssertThrowsError(try runner.runMigrationsIfNeeded(targetSchemaVersion: 2)) { error in
            guard case let MigrationRunnerError.backupFailed(required, _) = error else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertTrue(required)
        }
        XCTAssertTrue(recorder.appliedIdentifiers.isEmpty)
        XCTAssertEqual(backupService.recordedResult, .failed)
        XCTAssertEqual(schemaStore.currentSchemaVersion(), 1)
        XCTAssertEqual(schemaStore.lastSuccessfulMigrationVersion(), nil)
        XCTAssertNotNil(logStore.lastError())
        XCTAssertTrue(logStore.history(limit: nil).isEmpty)
    }

    func testRunnerContinuesWhenBackupFailsAndMigrationIsNotCritical() throws {
        let defaults = try makeDefaults()
        let schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        schemaStore.setCurrentSchemaVersion(1)

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let recorder = MigrationRecorder()
        let registry = try MigrationRegistry(
            migrations: [
                RecordingMigration(
                    id: "migration.v1_to_v2",
                    name: "v1 -> v2",
                    fromVersion: 1,
                    toVersion: 2,
                    requiresBackup: false,
                    recorder: recorder
                )
            ]
        )
        let backupService = FailingBackupService()
        let runner = MigrationRunner(
            schemaVersionStore: schemaStore,
            migrationRegistry: registry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: backupService
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 2)

        XCTAssertEqual(report.appliedMigrationIdentifiers, ["migration.v1_to_v2"])
        XCTAssertEqual(report.backupResult, .failed)
        XCTAssertNil(report.backupMetadata)
        XCTAssertEqual(recorder.appliedIdentifiers, ["migration.v1_to_v2"])
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SchemaMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class MigrationRecorder {
    var appliedIdentifiers: [String] = []
}

private struct RecordingMigration: Migration {
    let id: String
    let name: String
    let fromVersion: Int
    let toVersion: Int
    var isRequired: Bool
    var requiresBackup: Bool
    var recorder: MigrationRecorder?

    init(
        id: String,
        name: String,
        fromVersion: Int,
        toVersion: Int,
        isRequired: Bool = true,
        requiresBackup: Bool = false,
        recorder: MigrationRecorder? = nil
    ) {
        self.id = id
        self.name = name
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.isRequired = isRequired
        self.requiresBackup = requiresBackup
        self.recorder = recorder
    }

    func run(context: MigrationContext) throws {
        recorder?.appliedIdentifiers.append(id)
    }
}

private final class FailingBackupService: MigrationBackup.BackupService {
    private(set) var recordedResult: MigrationBackupResult?

    func createSnapshot(
        plan: [any Migration],
        fromVersion: Int,
        targetVersion: Int,
        context: MigrationContext
    ) throws -> MigrationBackupMetadata {
        throw MigrationBackupError.snapshotSerializationFailed(description: "forced")
    }

    func recordResult(
        _ result: MigrationBackupResult,
        metadata: MigrationBackupMetadata?
    ) {
        recordedResult = result
    }

    func state() -> MigrationBackupState {
        MigrationBackupState(backupResult: recordedResult)
    }

    func lastBackupDate() -> Date? {
        nil
    }

    func backupVersion() -> Int? {
        nil
    }

    func backupResult() -> MigrationBackupResult? {
        recordedResult
    }
}
#endif
