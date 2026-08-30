import Foundation

public struct CSVExportBuilder {
    private let delimiter: Character
    private let lineSeparator: String

    public init(delimiter: Character = ",", lineSeparator: String = "\n") {
        self.delimiter = delimiter
        self.lineSeparator = lineSeparator
    }

    public func buildCSV(header: [String], rows: [[String]]) -> String {
        var lines: [String] = []
        lines.reserveCapacity(rows.count + 1)

        lines.append(buildLine(header))
        lines.append(contentsOf: rows.map(buildLine))

        return lines.joined(separator: lineSeparator)
    }

    private func buildLine(_ columns: [String]) -> String {
        columns.map(escapedCell).joined(separator: String(delimiter))
    }

    private func escapedCell(_ cell: String) -> String {
        let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
        let needsQuotes = escaped.contains(delimiter) || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}
