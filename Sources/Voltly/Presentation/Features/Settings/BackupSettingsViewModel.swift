import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData
#endif

public enum BackupExportKind: String, Codable, Sendable {
    case fullJSON
    case sessionsCSV
    case iCloudJSON

    public var title: String {
        switch self {
        case .fullJSON:
            return "Tam Yedek (JSON)"
        case .sessionsCSV:
            return "Şarj Kayıtları (CSV)"
        case .iCloudJSON:
            return "iCloud Drive Yedeği (JSON)"
        }
    }
}

public struct BackupLastExportInfo: Equatable, Sendable {
    public let date: Date
    public let kind: BackupExportKind
    public let fileName: String

    public init(date: Date, kind: BackupExportKind, fileName: String) {
        self.date = date
        self.kind = kind
        self.fileName = fileName
    }
}

public enum BackupStatusStyle: Sendable {
    case info
    case success
    case warning
    case error
}

public struct BackupStatusMessage: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let style: BackupStatusStyle

    public init(title: String, detail: String, style: BackupStatusStyle) {
        self.title = title
        self.detail = detail
        self.style = style
    }
}

public struct BackupAlertState: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

@MainActor
public final class BackupSettingsViewModel: ObservableObject {
    @Published public private(set) var isPerformingAction = false
    @Published public var isShowingImportPicker = false
    @Published public private(set) var shareFileURL: URL?
    @Published public private(set) var lastExportInfo: BackupLastExportInfo?
    @Published public private(set) var lastImportResult: BackupImportResult?
    @Published public private(set) var lastImportedFileName: String?
    @Published public private(set) var statusMessage: BackupStatusMessage?
    @Published public var alertState: BackupAlertState?

    private let environment: AppEnvironment
    private let backupService: BackupServiceProtocol?
    private let iCloudDriveBackupService: ICloudDriveBackupServiceProtocol?
    private let sessionsCSVExportService: SessionsCSVExportServiceProtocol
    private let defaults: UserDefaults
    private let dateProvider: () -> Date
    private let backupUnavailableReason: String?

    private enum Keys {
        static let lastExportTimestamp = "backup.lastExport.timestamp"
        static let lastExportType = "backup.lastExport.type"
        static let lastExportFileName = "backup.lastExport.fileName"
    }

    private struct BackupBootstrapResult {
        let service: BackupServiceProtocol?
        let unavailableReason: String?
    }

    public init(
        environment: AppEnvironment,
        backupService: BackupServiceProtocol? = nil,
        iCloudDriveBackupService: ICloudDriveBackupServiceProtocol? = nil,
        sessionsCSVExportService: SessionsCSVExportServiceProtocol? = nil,
        defaults: UserDefaults = .standard,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.environment = environment
        self.defaults = defaults
        self.dateProvider = dateProvider

        let resolvedCSVService = sessionsCSVExportService ?? SessionsCSVExportService(
            listSessionsUseCase: environment.listChargingSessionsUseCase,
            vehicleRepository: environment.vehicleRepository
        )
        self.sessionsCSVExportService = resolvedCSVService

        let resolvedBackupService: BackupServiceProtocol?
        let resolvedUnavailableReason: String?

        if let backupService {
            resolvedBackupService = backupService
            resolvedUnavailableReason = nil
        } else {
            let bootstrap = Self.bootstrapBackupService(sessionsCSVExportService: resolvedCSVService)
            resolvedBackupService = bootstrap.service
            resolvedUnavailableReason = bootstrap.unavailableReason
        }

        self.backupService = resolvedBackupService
        self.backupUnavailableReason = resolvedUnavailableReason
        if let iCloudDriveBackupService {
            self.iCloudDriveBackupService = iCloudDriveBackupService
        } else if let resolvedBackupService {
            self.iCloudDriveBackupService = ICloudDriveBackupService(backupService: resolvedBackupService)
        } else {
            self.iCloudDriveBackupService = nil
        }

        loadPersistedState()
    }

    public func exportFullBackupJSON() {
        guard let backupService else {
            let reason = backupUnavailableReason ?? "Tam yedekleme şu anda kullanılamıyor."
            Haptics.error()
            publishStatus(
                title: "Yedekleme kullanılamıyor",
                detail: reason,
                style: .error,
                alert: true
            )
            return
        }

        performAction {
            let fileURL = try backupService.exportBackup(to: nil)
            handleExportSuccess(url: fileURL, kind: .fullJSON)
        }
    }

    public func exportChargingSessionsCSV() {
        performAction {
            let fileURL = try sessionsCSVExportService.exportChargingSessionsCSV(to: nil)
            handleExportSuccess(url: fileURL, kind: .sessionsCSV)
        }
    }

    public func exportFullBackupToICloudDrive() {
        guard let iCloudDriveBackupService else {
            Haptics.error()
            publishStatus(
                title: "iCloud Drive yedekleme kullanılamıyor",
                detail: "Önce JSON yedekleme altyapısı başlatılmalı.",
                style: .error,
                alert: true
            )
            return
        }

        performAction {
            let fileURL = try iCloudDriveBackupService.exportBackupToICloudDrive()
            handleExportSuccess(
                url: fileURL,
                kind: .iCloudJSON,
                detail: "Yedek iCloud Drive/VoltlyBackups klasörüne kaydedildi."
            )
        } onError: { [weak self] error in
            self?.handleICloudExportError(error)
        }
    }

    public func startImportFlow() {
        Haptics.selection()
        isShowingImportPicker = true
    }

    public func handleImportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let fileURL):
            importBackup(from: fileURL)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == NSUserCancelledError {
                return
            }
            Haptics.error()
            publishStatus(
                title: "İçe aktarma başlatılamadı",
                detail: error.localizedDescription,
                style: .error,
                alert: true
            )
        }
    }

    public func importBackup(from fileURL: URL) {
        guard let backupService else {
            let reason = backupUnavailableReason ?? "İçe aktarma şu anda kullanılamıyor."
            Haptics.error()
            publishStatus(
                title: "İçe aktarma kullanılamıyor",
                detail: reason,
                style: .error,
                alert: true
            )
            return
        }

        performAction {
            let result = try backupService.importBackup(from: fileURL)
            lastImportResult = result
            lastImportedFileName = fileURL.lastPathComponent
            shareFileURL = nil
            AppDataChangeNotifier.post(reason: .backupImport)

            if result.failedCount == 0, result.warnings.isEmpty {
                Haptics.success()
                publishStatus(
                    title: "İçe aktarma başarılı",
                    detail: "Yedek dosyası sorunsuz şekilde içe aktarıldı.",
                    style: .success,
                    alert: true
                )
            } else {
                Haptics.error()
                publishStatus(
                    title: "İçe aktarma tamamlandı",
                    detail: "Bazı kayıtlar atlandı veya uyarı üretildi. Özet bölümünü kontrol et.",
                    style: .warning,
                    alert: true
                )
            }
        } onError: { [weak self] error in
            self?.handleImportError(error)
        }
    }

    private func handleImportError(_ error: Error) {
        Haptics.error()
        if let validationError = error as? BackupValidationError {
            switch validationError {
            case .corruptedJSON, .invalidArchive:
                publishStatus(
                    title: "Geçersiz dosya",
                    detail: validationError.localizedDescription,
                    style: .error,
                    alert: true
                )
            case .unsupportedSchemaVersion:
                publishStatus(
                    title: "Sürüm uyumsuzluğu",
                    detail: validationError.localizedDescription,
                    style: .error,
                    alert: true
                )
            case .fileNotFound, .unreadableFile:
                publishStatus(
                    title: "Dosya açılamadı",
                    detail: validationError.localizedDescription,
                    style: .error,
                    alert: true
                )
            }
            return
        }

        publishStatus(
            title: "Beklenmeyen hata",
            detail: error.localizedDescription,
            style: .error,
            alert: true
        )
    }

    private func handleICloudExportError(_ error: Error) {
        Haptics.error()
        if let iCloudError = error as? ICloudDriveBackupError {
            publishStatus(
                title: "iCloud Drive yedekleme başarısız",
                detail: iCloudError.localizedDescription,
                style: .error,
                alert: true
            )
            return
        }

        publishStatus(
            title: "iCloud Drive yedekleme başarısız",
            detail: error.localizedDescription,
            style: .error,
            alert: true
        )
    }

    private func performAction(
        _ action: () throws -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try action()
        } catch {
            if let onError {
                onError(error)
            } else {
                publishStatus(
                    title: "İşlem başarısız",
                    detail: error.localizedDescription,
                    style: .error,
                    alert: true
                )
            }
        }
    }

    private func handleExportSuccess(
        url: URL,
        kind: BackupExportKind,
        detail: String? = nil
    ) {
        Haptics.success()
        shareFileURL = url
        let info = BackupLastExportInfo(
            date: dateProvider(),
            kind: kind,
            fileName: url.lastPathComponent
        )
        lastExportInfo = info
        persistLastExportInfo(info)

        publishStatus(
            title: "Dışa aktarma tamamlandı",
            detail: detail ?? "\(kind.title) dosyası hazır. İstersen hemen paylaşabilirsin.",
            style: .success,
            alert: true
        )
    }

    private func publishStatus(
        title: String,
        detail: String,
        style: BackupStatusStyle,
        alert: Bool
    ) {
        statusMessage = BackupStatusMessage(title: title, detail: detail, style: style)
        if alert {
            alertState = BackupAlertState(title: title, message: detail)
        }
    }

    private func loadPersistedState() {
        guard let timestamp = defaults.object(forKey: Keys.lastExportTimestamp) as? Date,
              let kindRaw = defaults.string(forKey: Keys.lastExportType),
              let kind = BackupExportKind(rawValue: kindRaw),
              let fileName = defaults.string(forKey: Keys.lastExportFileName),
              !fileName.isEmpty else {
            return
        }

        lastExportInfo = BackupLastExportInfo(date: timestamp, kind: kind, fileName: fileName)
    }

    private func persistLastExportInfo(_ info: BackupLastExportInfo) {
        defaults.set(info.date, forKey: Keys.lastExportTimestamp)
        defaults.set(info.kind.rawValue, forKey: Keys.lastExportType)
        defaults.set(info.fileName, forKey: Keys.lastExportFileName)
    }

    private static func bootstrapBackupService(
        sessionsCSVExportService: SessionsCSVExportServiceProtocol
    ) -> BackupBootstrapResult {
        #if VOLTLY_ENABLE_SWIFTDATA
        do {
            let container = try SwiftDataFactory.makeModelContainer()
            let context = ModelContext(container)
            let service = BackupService(
                exportService: ExportService(context: context),
                sessionsCSVExportService: sessionsCSVExportService,
                importService: ImportService(context: context)
            )
            return BackupBootstrapResult(service: service, unavailableReason: nil)
        } catch {
            return BackupBootstrapResult(
                service: nil,
                unavailableReason: "Yedekleme altyapısı başlatılamadı: \(error.localizedDescription)"
            )
        }
        #else
        return BackupBootstrapResult(
            service: nil,
            unavailableReason: "Bu platformda JSON yedekleme desteklenmiyor."
        )
        #endif
    }
}

#if DEBUG
private struct PreviewBackupService: BackupServiceProtocol {
    func exportBackup(to directoryURL: URL?) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-backup.json")
        try "{}".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportChargingSessionsCSV(to directoryURL: URL?) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-sessions.csv")
        try "Date,Vehicle\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func importBackup(from fileURL: URL) throws -> BackupImportResult {
        BackupImportResult(
            insertedCount: 3,
            updatedCount: 1,
            skippedCount: 2,
            failedCount: 0,
            warnings: []
        )
    }
}

private struct PreviewSessionsCSVExportService: SessionsCSVExportServiceProtocol {
    func exportChargingSessionsCSV(to directoryURL: URL?) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-csv-only.csv")
        try "Date,Vehicle\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

extension BackupSettingsViewModel {
    public static func preview() -> BackupSettingsViewModel {
        let environment = try! AppEnvironment.live(inMemory: true)
        return BackupSettingsViewModel(
            environment: environment,
            backupService: PreviewBackupService(),
            iCloudDriveBackupService: PreviewICloudDriveBackupService(),
            sessionsCSVExportService: PreviewSessionsCSVExportService()
        )
    }
}

private struct PreviewICloudDriveBackupService: ICloudDriveBackupServiceProtocol {
    func exportBackupToICloudDrive() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-icloud-backup.json")
        try "{}".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
#endif
