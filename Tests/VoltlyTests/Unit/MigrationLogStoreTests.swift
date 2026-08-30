#if canImport(XCTest)
import XCTest
@testable import Voltly

final class MigrationLogStoreTests: XCTestCase {
    func testStoreAppendsLogsAndHistoryAndClearsState() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsMigrationLogStore(defaults: defaults)

        store.appendLog(
            MigrationLogEntry(
                createdAt: Date(timeIntervalSince1970: 10),
                level: .info,
                message: "Migration kontrolu basladi.",
                metadata: ["targetSchema": "6"]
            )
        )
        store.appendHistory(
            MigrationHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 20),
                migrationID: "migration.v1_to_v2",
                migrationName: "v1 -> v2",
                fromVersion: 1,
                toVersion: 2,
                durationMs: 12,
                status: .success
            )
        )
        store.setLastError(
            MigrationStoredError(
                message: "test error",
                createdAt: Date(timeIntervalSince1970: 30)
            )
        )

        XCTAssertEqual(store.logs(limit: nil).count, 1)
        XCTAssertEqual(store.history(limit: nil).count, 1)
        XCTAssertEqual(store.lastError()?.message, "test error")

        store.clearAll()

        XCTAssertTrue(store.logs(limit: nil).isEmpty)
        XCTAssertTrue(store.history(limit: nil).isEmpty)
        XCTAssertNil(store.lastError())
    }

    func testStoreKeepsNewestEntriesFirst() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsMigrationLogStore(defaults: defaults)

        store.appendLog(
            MigrationLogEntry(
                createdAt: Date(timeIntervalSince1970: 1),
                level: .info,
                message: "old",
                metadata: [:]
            )
        )
        store.appendLog(
            MigrationLogEntry(
                createdAt: Date(timeIntervalSince1970: 2),
                level: .warning,
                message: "new",
                metadata: [:]
            )
        )

        let logs = store.logs(limit: nil)
        XCTAssertEqual(logs.first?.message, "new")
        XCTAssertEqual(logs.last?.message, "old")
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "MigrationLogStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
