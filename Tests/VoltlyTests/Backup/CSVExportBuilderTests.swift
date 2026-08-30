#if canImport(XCTest)
import XCTest
@testable import Voltly

final class CSVExportBuilderTests: XCTestCase {
    func testBuildCSVIncludesHeaderRow() {
        let builder = CSVExportBuilder()

        let csv = builder.buildCSV(
            header: ["Date", "Station", "Total Price"],
            rows: [
                ["2026-03-11", "ZES", "245.0"],
                ["2026-03-12", "Trugo", "310.5"]
            ]
        )

        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "Date,Station,Total Price")
        XCTAssertEqual(lines[1], "2026-03-11,ZES,245.0")
        XCTAssertEqual(lines[2], "2026-03-12,Trugo,310.5")
    }

    func testBuildCSVEscapesCommasQuotesAndMultilineValues() {
        let builder = CSVExportBuilder()
        let note = "Levent, \"Hizli\"\nIkinci satir"

        let csv = builder.buildCSV(
            header: ["Note"],
            rows: [[note]]
        )

        XCTAssertEqual(csv, "Note\n\"Levent, \"\"Hizli\"\"\nIkinci satir\"")
    }
}
#endif
