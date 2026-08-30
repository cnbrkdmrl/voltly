import Foundation

/// V1.1 iCloud Drive yedekleme aksiyonları için servis sözleşmesi.
public protocol ICloudDriveBackupServiceProtocol {
    func exportBackupToICloudDrive() throws -> URL
}

/// iCloud Drive yedekleme katmanı için kullanıcı dostu hata tipleri.
public enum ICloudDriveBackupError: LocalizedError, Sendable {
    case iCloudUnavailable
    case inaccessibleContainer
    case writeFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive kullanılamıyor. iCloud hesabın ve uygulama iCloud yetkileri kontrol edilmeli."
        case .inaccessibleContainer:
            return "iCloud Drive klasörüne erişilemedi."
        case .writeFailed(let reason):
            return "iCloud Drive yedeği yazılamadı: \(reason)"
        }
    }
}
