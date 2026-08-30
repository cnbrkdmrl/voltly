#if canImport(XCTest)
import XCTest
@testable import Voltly

final class MigrationRunnerCoverageTests: XCTestCase {
    func testFreshInstallInitializesSchemaWithoutRunningMigrations() throws {
        let store = MockSchemaVersionStore(current: nil)
        let backup = MockBackupService()
        let migration = CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [migration]
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 2)

        XCTAssertTrue(report.initializedOnFirstInstall)
        XCTAssertEqual(report.appliedMigrationIdentifiers, [])
        XCTAssertEqual(store.currentSchemaVersion(), 2)
        XCTAssertEqual(store.lastSuccessfulMigrationVersion(), 2)
        XCTAssertEqual(migration.runCount, 0)
        XCTAssertEqual(backup.createSnapshotCallCount, 0)
    }

    func testUpgradeFromOldSchemaToNewVersionRunsSingleStepMigration() throws {
        let store = MockSchemaVersionStore(current: 2)
        let backup = MockBackupService()
        let migration = CountingMigration(id: "m.v2_to_v3", from: 2, to: 3)
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [migration]
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)

        XCTAssertEqual(report.appliedMigrationIdentifiers, ["m.v2_to_v3"])
        XCTAssertEqual(store.currentSchemaVersion(), 3)
        XCTAssertEqual(migration.runCount, 1)
    }

    func testMultiStepMigrationChainRunsInOrder() throws {
        let store = MockSchemaVersionStore(current: 1)
        let backup = MockBackupService()
        let recorder = MigrationOrderRecorder()
        let m1 = CountingMigration(
            id: "m.v1_to_v2",
            from: 1,
            to: 2,
            recorder: recorder
        )
        let m2 = CountingMigration(
            id: "m.v2_to_v3",
            from: 2,
            to: 3,
            recorder: recorder
        )
        let m3 = CountingMigration(
            id: "m.v3_to_v4",
            from: 3,
            to: 4,
            recorder: recorder
        )
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [m1, m2, m3]
        )

        let report = try runner.runMigrationsIfNeeded(targetSchemaVersion: 4)

        XCTAssertEqual(
            report.appliedMigrationIdentifiers,
            ["m.v1_to_v2", "m.v2_to_v3", "m.v3_to_v4"]
        )
        XCTAssertEqual(recorder.appliedOrder, report.appliedMigrationIdentifiers)
        XCTAssertEqual(store.currentSchemaVersion(), 4)
    }

    func testMissingMigrationStepThrowsValidationError() throws {
        let store = MockSchemaVersionStore(current: 1)
        let backup = MockBackupService()
        let migration = CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [migration]
        )

        XCTAssertThrowsError(try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)) { error in
            XCTAssertEqual(
                error as? MigrationRunnerError,
                .registryValidationFailed(.missingStep(fromVersion: 2, targetVersion: 3))
            )
        }
        XCTAssertEqual(store.currentSchemaVersion(), 1)
    }

    func testDuplicateMigrationIDFailsRegistryInitialization() throws {
        XCTAssertThrowsError(
            try MigrationRegistry(
                migrations: [
                    CountingMigration(id: "duplicate", from: 1, to: 2),
                    CountingMigration(id: "duplicate", from: 2, to: 3)
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? MigrationRegistryValidationError,
                .duplicateID("duplicate")
            )
        }
    }

    func testOutOfOrderMigrationDefinitionProducesWarning() throws {
        let registry = try MigrationRegistry(
            migrations: [
                CountingMigration(id: "m.v2_to_v3", from: 2, to: 3),
                CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
            ]
        )

        let validation = try registry.validate(from: 1, to: 3)
        XCTAssertEqual(validation.warnings.count, 1)
        XCTAssertEqual(validation.warnings.first?.code, "ORDER_MISMATCH")
    }

    func testRunnerIsIdempotentWhenCalledAgainAtTargetSchema() throws {
        let store = MockSchemaVersionStore(current: 1)
        let backup = MockBackupService()
        let m1 = CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
        let m2 = CountingMigration(id: "m.v2_to_v3", from: 2, to: 3)
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [m1, m2]
        )

        let first = try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)
        let second = try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)

        XCTAssertEqual(first.appliedMigrationIdentifiers, ["m.v1_to_v2", "m.v2_to_v3"])
        XCTAssertEqual(second.appliedMigrationIdentifiers, [])
        XCTAssertEqual(m1.runCount, 1)
        XCTAssertEqual(m2.runCount, 1)
        XCTAssertEqual(backup.createSnapshotCallCount, 1)
    }

    func testFeatureFlagMigrationFromV5ToV6CreatesExpectedFlagValues() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsSchemaVersionStore(defaults: defaults)
        store.setCurrentSchemaVersion(LocalSchemaVersion.v5.rawValue)

        defaults.set(
            [
                "insights.micro.enabled": false,
                "charge.smart_repeat.enabled": true
            ],
            forKey: FeatureFlagConstants.storageKey
        )

        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let context = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let runner = MigrationRunner(
            schemaVersionStore: store,
            migrationRegistry: try MigrationRegistry.makeDefault(),
            migrationContext: context,
            appVersionManager: appVersionManager,
            backupService: MockBackupService(),
            migrationLogStore: UserDefaultsMigrationLogStore(defaults: defaults),
            logger: MigrationLogStoreLogger(store: UserDefaultsMigrationLogStore(defaults: defaults))
        )

        _ = try runner.runMigrationsIfNeeded(targetSchemaVersion: LocalSchemaVersion.current.rawValue)

        let flags = try XCTUnwrap(defaults.dictionary(forKey: FeatureFlagConstants.storageKey))
        XCTAssertEqual(flags[AppFeature.advancedInsights.key] as? Bool, false)
        XCTAssertEqual(flags[AppFeature.smartRecommendations.key] as? Bool, true)
        XCTAssertEqual(flags[AppFeature.savingsBankV2.key] as? Bool, false)
        XCTAssertEqual(flags[AppFeature.exportPDF.key] as? Bool, false)
        XCTAssertEqual(flags[AppFeature.betaDashboardCards.key] as? Bool, false)
    }

    func testBackupIsTriggeredBeforeMigrationPlanExecution() throws {
        let store = MockSchemaVersionStore(current: 1)
        let backup = MockBackupService()
        let migration = CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [migration]
        )

        _ = try runner.runMigrationsIfNeeded(targetSchemaVersion: 2)

        XCTAssertEqual(backup.createSnapshotCallCount, 1)
        XCTAssertEqual(backup.lastFromVersion, 1)
        XCTAssertEqual(backup.lastTargetVersion, 2)
        XCTAssertEqual(backup.lastPlannedMigrationIDs, ["m.v1_to_v2"])
    }

    func testSchemaVersionDoesNotAdvancePastFailedMigration() throws {
        let store = MockSchemaVersionStore(current: 1)
        let backup = MockBackupService()
        let success = CountingMigration(id: "m.v1_to_v2", from: 1, to: 2)
        let failing = CountingMigration(
            id: "m.v2_to_v3",
            from: 2,
            to: 3,
            errorToThrow: StubError.marker
        )
        let runner = try makeRunner(
            store: store,
            backup: backup,
            migrations: [success, failing]
        )

        XCTAssertThrowsError(try runner.runMigrationsIfNeeded(targetSchemaVersion: 3)) { error in
            guard case let MigrationRunnerError.executionFailed(migrationID, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(migrationID, "m.v2_to_v3")
        }

        XCTAssertEqual(success.runCount, 1)
        XCTAssertEqual(failing.runCount, 1)
        XCTAssertEqual(store.currentSchemaVersion(), 2)
        XCTAssertEqual(store.lastSuccessfulMigrationVersion(), 2)
    }

    private func makeRunner(
        store: any SchemaVersionStore,
        backup: MockBackupService,
        migrations: [any Migration]
    ) throws -> MigrationRunner {
        let defaults = try makeDefaults()
        let appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        let context = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let registry = try MigrationRegistry(migrations: migrations)
        let logStore = UserDefaultsMigrationLogStore(defaults: defaults)
        return MigrationRunner(
            schemaVersionStore: store,
            migrationRegistry: registry,
            migrationContext: context,
            appVersionManager: appVersionManager,
            backupService: backup,
            migrationLogStore: logStore,
            logger: MigrationLogStoreLogger(store: logStore)
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "MigrationRunnerCoverageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private enum StubError: Error {
    case marker
}

private final class MigrationOrderRecorder {
    var appliedOrder: [String] = []
}

private final class CountingMigration: Migration {
    let id: String
    let name: String
    let fromVersion: Int
    let toVersion: Int
    let isRequired: Bool
    let requiresBackup: Bool

    private let recorder: MigrationOrderRecorder?
    private let errorToThrow: Error?
    private(set) var runCount = 0

    init(
        id: String,
        from: Int,
        to: Int,
        isRequired: Bool = true,
        requiresBackup: Bool = false,
        recorder: MigrationOrderRecorder? = nil,
        errorToThrow: Error? = nil
    ) {
        self.id = id
        self.name = id
        self.fromVersion = from
        self.toVersion = to
        self.isRequired = isRequired
        self.requiresBackup = requiresBackup
        self.recorder = recorder
        self.errorToThrow = errorToThrow
    }

    func run(context: MigrationContext) throws {
        runCount += 1
        recorder?.appliedOrder.append(id)
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

private final class MockSchemaVersionStore: SchemaVersionStore {
    private var state: SchemaVersionState

    init(current: Int?) {
        state = SchemaVersionState(currentSchemaVersion: current)
    }

    func currentSchemaVersion() -> Int? { state.currentSchemaVersion }
    func setCurrentSchemaVersion(_ version: Int) { state.currentSchemaVersion = version }
    func isFreshInstall() -> Bool { state.currentSchemaVersion == nil }
    func firstInstallDate() -> Date? { state.firstInstallDate }
    func lastSuccessfulMigrationVersion() -> Int? { state.lastSuccessfulMigrationVersion }
    func lastMigrationDate() -> Date? { state.lastMigrationDate }

    func markFreshInstall(defaultSchemaVersion: Int, at date: Date) {
        guard state.currentSchemaVersion == nil else { return }
        state.currentSchemaVersion = defaultSchemaVersion
        state.firstInstallDate = date
        state.lastSuccessfulMigrationVersion = defaultSchemaVersion
        state.lastMigrationDate = date
    }

    func recordSuccessfulMigration(to version: Int, at date: Date) {
        state.currentSchemaVersion = version
        state.firstInstallDate = state.firstInstallDate ?? date
        state.lastSuccessfulMigrationVersion = version
        state.lastMigrationDate = date
    }
}

private final class MockBackupService: MigrationBackup.BackupService {
    var createSnapshotCallCount = 0
    var lastFromVersion: Int?
    var lastTargetVersion: Int?
    var lastPlannedMigrationIDs: [String] = []

    private var internalState = MigrationBackupState()

    func createSnapshot(
        plan: [any Migration],
        fromVersion: Int,
        targetVersion: Int,
        context: MigrationContext
    ) throws -> MigrationBackupMetadata {
        createSnapshotCallCount += 1
        lastFromVersion = fromVersion
        lastTargetVersion = targetVersion
        lastPlannedMigrationIDs = plan.map(\.id)

        return MigrationBackupMetadata(
            backupID: "mock-backup-\(createSnapshotCallCount)",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            backupVersion: fromVersion,
            targetSchemaVersion: targetVersion,
            migrationIdentifiers: plan.map(\.id),
            filePath: "/tmp/mock-backup-\(createSnapshotCallCount).json"
        )
    }

    func recordResult(
        _ result: MigrationBackupResult,
        metadata: MigrationBackupMetadata?
    ) {
        internalState.backupResult = result
        internalState.lastBackupMetadata = metadata
        internalState.lastBackupDate = metadata?.createdAt
        internalState.backupVersion = metadata?.backupVersion
    }

    func state() -> MigrationBackupState {
        internalState
    }
}
#endif
