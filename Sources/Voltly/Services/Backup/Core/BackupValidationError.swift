import Foundation

public enum BackupValidationError: LocalizedError, Equatable, Sendable {
    case fileNotFound(URL)
    case unreadableFile(URL)
    case corruptedJSON
    case unsupportedSchemaVersion(expected: Int, found: Int)
    case invalidArchive(reason: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Yedek dosyasi bulunamadi: \(url.lastPathComponent)"
        case .unreadableFile(let url):
            return "Yedek dosyasi okunamadi: \(url.lastPathComponent)"
        case .corruptedJSON:
            return "Yedek dosyasi bozuk veya gecersiz JSON iceriyor."
        case .unsupportedSchemaVersion(let expected, let found):
            return "Desteklenmeyen yedek surumu. Beklenen: \(expected), bulunan: \(found)."
        case .invalidArchive(let reason):
            return "Gecersiz yedek arsivi: \(reason)"
        }
    }
}
