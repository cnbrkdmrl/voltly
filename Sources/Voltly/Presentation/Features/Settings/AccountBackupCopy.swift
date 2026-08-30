import Foundation

public struct AccountBackupStatusContent: Equatable {
    public let title: String
    public let detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}

public enum AccountBackupCopy {
    public static let statusLabel = "Yedekleme durumu"
    public static let lastBackupLabel = "Son yedekleme"
    public static let triggerBackupAction = "Verileri yedekle"
    public static let signInRequiredMessage = "Yedekleme için önce hesabına giriş yap."
    public static let backupCompletedMessage = "Verilerin yedeklendi."
    public static let backupFailedMessage = "Yedekleme tamamlanamadı. Bağlantı geldiğinde tekrar denenecek."

    public static func content(for status: AccountSyncStatus) -> AccountBackupStatusContent {
        switch status {
        case .idle:
            return AccountBackupStatusContent(
                title: "Yedeklenmedi",
                detail: "Henüz manuel bir yedekleme başlatılmadı."
            )
        case .syncing:
            return AccountBackupStatusContent(
                title: "Yedekleniyor",
                detail: "Kısa süre içinde tamamlanır."
            )
        case .success:
            return AccountBackupStatusContent(
                title: "Veriler yedeklendi",
                detail: "Kayıtların güvenle saklanıyor."
            )
        case .failed:
            return AccountBackupStatusContent(
                title: "Yedeklenmedi",
                detail: "Bağlantı geldiğinde tekrar denenecek."
            )
        }
    }
}
