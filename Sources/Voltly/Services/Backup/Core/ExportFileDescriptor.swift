import Foundation

public enum ExportFileFormat: String, Sendable {
    case json
    case csv

    public var fileExtension: String {
        rawValue
    }
}

public struct ExportFileDescriptor: Equatable, Sendable {
    public let category: String
    public let format: ExportFileFormat
    public let timestamp: Date
    public let directoryName: String

    public init(
        category: String,
        format: ExportFileFormat,
        timestamp: Date,
        directoryName: String = "VoltlyExports"
    ) {
        self.category = category
        self.format = format
        self.timestamp = timestamp
        self.directoryName = directoryName
    }

    public var fileName: String {
        "voltly-\(category)-\(Self.timestampFormatter.string(from: timestamp)).\(format.fileExtension)"
    }

    public static func sessionsCSV(at timestamp: Date) -> ExportFileDescriptor {
        ExportFileDescriptor(
            category: "charging-sessions",
            format: .csv,
            timestamp: timestamp
        )
    }

    public static func backupJSON(at timestamp: Date) -> ExportFileDescriptor {
        ExportFileDescriptor(
            category: "backup-v1",
            format: .json,
            timestamp: timestamp
        )
    }

    private static var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
