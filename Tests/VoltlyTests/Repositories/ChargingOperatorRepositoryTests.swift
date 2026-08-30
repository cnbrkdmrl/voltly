#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ChargingOperatorRepositoryTests: XCTestCase {
    func testSeedImportIsIdempotentAndPreventsDuplicatesByOperatorCode() throws {
        let repository = try makeRepository()

        try repository.seedIfNeeded()
        let firstImport = try repository.visibleOperators()
        XCTAssertFalse(firstImport.isEmpty)

        try repository.seedIfNeeded()
        let secondImport = try repository.visibleOperators()

        XCTAssertEqual(firstImport.count, secondImport.count)
        XCTAssertNotNil(try repository.operator(byCode: "zes"))
        XCTAssertNotNil(try repository.operator(byCode: "ZES"))
    }

    func testSortingAndFavoritePriority() throws {
        let repository = try makeRepository()
        try repository.seedIfNeeded()

        try repository.setFavorite(operatorCode: "trugo", isFavorite: true)
        try repository.setFavorite(operatorCode: "zes", isFavorite: true)

        let sorted = try repository.visibleOperators()
        XCTAssertGreaterThanOrEqual(sorted.count, 2)
        XCTAssertEqual(sorted[0].operatorCode, "trugo")
        XCTAssertEqual(sorted[1].operatorCode, "zes")
    }

    func testHideAndUnhideOperator() throws {
        let repository = try makeRepository()
        try repository.seedIfNeeded()

        try repository.setHidden(operatorCode: "ionity", isHidden: true)
        let visible = try repository.visibleOperators()
        XCTAssertFalse(visible.contains(where: { $0.operatorCode == "ionity" }))

        let hidden = try repository.hiddenOperators()
        XCTAssertTrue(hidden.contains(where: { $0.operatorCode == "ionity" }))

        try repository.setHidden(operatorCode: "ionity", isHidden: false)
        let visibleAfterUnhide = try repository.visibleOperators()
        XCTAssertTrue(visibleAfterUnhide.contains(where: { $0.operatorCode == "ionity" }))
    }

    private func makeRepository() throws -> SQLiteChargingOperatorRepository {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltly_tests", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let dbURL = tempDirectory.appendingPathComponent("operators_\(UUID().uuidString).sqlite")
        return try SQLiteChargingOperatorRepository(databaseURL: dbURL)
    }
}
#endif
