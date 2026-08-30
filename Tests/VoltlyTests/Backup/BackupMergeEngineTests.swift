#if canImport(XCTest)
import XCTest
@testable import Voltly

final class BackupMergeEngineTests: XCTestCase {
    func testDecideReturnsInsertedWhenLocalRecordMissing() {
        let engine = BackupMergeEngine()
        let incoming = MergeFixture.record(updatedAt: date(120))

        let decision = engine.decide(local: Optional<MergeFixture>.none, incoming: incoming)

        XCTAssertEqual(decision, .inserted)
    }

    func testDecideReturnsUpdatedWhenIncomingIsNewer() {
        let engine = BackupMergeEngine()
        let id = UUID()
        let local = MergeFixture.record(id: id, updatedAt: date(100), isDeleted: false)
        let incoming = MergeFixture.record(id: id, updatedAt: date(150), isDeleted: false)

        let decision = engine.decide(local: local, incoming: incoming)

        XCTAssertEqual(decision, .updated)
    }

    func testDecideReturnsSkippedWhenIncomingIsOlder() {
        let engine = BackupMergeEngine()
        let id = UUID()
        let local = MergeFixture.record(id: id, updatedAt: date(200), isDeleted: false)
        let incoming = MergeFixture.record(id: id, updatedAt: date(150), isDeleted: false)

        let decision = engine.decide(local: local, incoming: incoming)

        XCTAssertEqual(decision, .skipped)
    }

    func testDecideFailsWhenUUIDDoesNotMatch() {
        let engine = BackupMergeEngine()
        let local = MergeFixture.record(id: UUID(), updatedAt: date(100), isDeleted: false)
        let incoming = MergeFixture.record(id: UUID(), updatedAt: date(200), isDeleted: false)

        let decision = engine.decide(local: local, incoming: incoming)

        switch decision {
        case .failed(let reason):
            XCTAssertTrue(reason.contains("kimligi"))
        default:
            XCTFail("Beklenen karar failed olmaliydi, gelen: \(decision)")
        }
    }

    func testSoftDeletedIncomingRecordUpdatesWhenNewer() {
        let engine = BackupMergeEngine()
        let id = UUID()
        let local = MergeFixture.record(id: id, updatedAt: date(100), isDeleted: false)
        let incoming = MergeFixture.record(id: id, updatedAt: date(200), isDeleted: true)

        let decision = engine.decide(local: local, incoming: incoming)

        XCTAssertEqual(decision, .updated)
    }

    func testSoftDeletedIncomingRecordIsSkippedWhenOlder() {
        let engine = BackupMergeEngine()
        let id = UUID()
        let local = MergeFixture.record(id: id, updatedAt: date(300), isDeleted: false)
        let incoming = MergeFixture.record(id: id, updatedAt: date(200), isDeleted: true)

        let decision = engine.decide(local: local, incoming: incoming)

        XCTAssertEqual(decision, .skipped)
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}

private struct MergeFixture: SyncCandidate {
    let id: UUID
    let syncMetadata: SyncMetadata

    static func record(
        id: UUID = UUID(),
        updatedAt: Date,
        schemaVersion: Int = AppSchemaVersion.current.rawValue,
        isDeleted: Bool = false
    ) -> MergeFixture {
        MergeFixture(
            id: id,
            syncMetadata: SyncMetadata(
                updatedAt: updatedAt,
                schemaVersion: schemaVersion,
                isDeleted: isDeleted
            )
        )
    }
}
#endif
