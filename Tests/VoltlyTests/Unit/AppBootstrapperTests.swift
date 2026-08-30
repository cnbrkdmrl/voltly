#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class AppBootstrapperTests: XCTestCase {
    func testPrepareMarksMigrationRequiredWhenSchemaIsOlderThanTarget() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsSchemaVersionStore(defaults: defaults)
        store.setCurrentSchemaVersion(1)

        let bootstrapper = AppBootstrapper(
            defaults: defaults,
            targetSchemaVersion: 2,
            migrationExecutor: { _, _, _ in
                XCTFail("Migration executor should not run during prepare")
                throw StubError.marker
            },
            environmentBuilder: {
                XCTFail("Environment builder should not run during prepare")
                throw StubError.marker
            }
        )

        let preparation = bootstrapper.prepare()

        XCTAssertEqual(preparation.currentSchemaVersion, 1)
        XCTAssertEqual(preparation.targetSchemaVersion, 2)
        XCTAssertTrue(preparation.requiresMigration)
        XCTAssertFalse(preparation.isFreshInstall)
    }

    func testBootstrapWrapsMigrationFailureWithStageContext() throws {
        let defaults = try makeDefaults()
        let bootstrapper = AppBootstrapper(
            defaults: defaults,
            targetSchemaVersion: 2,
            migrationExecutor: { _, _, _ in
                throw StubError.marker
            },
            environmentBuilder: {
                XCTFail("Environment builder should not run when migration fails")
                throw StubError.marker
            }
        )

        XCTAssertThrowsError(try bootstrapper.bootstrap()) { error in
            guard case let AppBootstrapperError.migrationFailed(preparation, underlying) = error else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(preparation.targetSchemaVersion, 2)
            XCTAssertEqual(underlying as? StubError, .marker)
        }
    }

    func testBootstrapWrapsEnvironmentFailureAfterMigrationReport() throws {
        let defaults = try makeDefaults()
        let migrationReport = MigrationRunReport(
            previousSchemaVersion: 1,
            targetSchemaVersion: 2,
            appliedMigrationIdentifiers: ["migration.v1_to_v2"],
            initializedOnFirstInstall: false,
            previousAppVersion: nil,
            currentAppVersion: AppReleaseVersion(appVersion: "1.0.0", buildNumber: "1"),
            warnings: [],
            traces: []
        )
        let bootstrapper = AppBootstrapper(
            defaults: defaults,
            targetSchemaVersion: 2,
            migrationExecutor: { _, _, _ in
                migrationReport
            },
            environmentBuilder: {
                throw StubError.marker
            }
        )

        XCTAssertThrowsError(try bootstrapper.bootstrap()) { error in
            guard case let AppBootstrapperError.environmentFailed(_, report, underlying) = error else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(report.appliedMigrationIdentifiers, ["migration.v1_to_v2"])
            XCTAssertEqual(underlying as? StubError, .marker)
        }
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "AppBootstrapperTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private enum StubError: Error {
    case marker
}
#endif
