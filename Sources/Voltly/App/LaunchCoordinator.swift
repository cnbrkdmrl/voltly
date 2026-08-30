import Foundation
import Combine

public struct AppBootstrapPreparation: Sendable {
    public let currentSchemaVersion: Int?
    public let targetSchemaVersion: Int
    public let appVersion: AppReleaseVersion

    public init(
        currentSchemaVersion: Int?,
        targetSchemaVersion: Int,
        appVersion: AppReleaseVersion
    ) {
        self.currentSchemaVersion = currentSchemaVersion
        self.targetSchemaVersion = targetSchemaVersion
        self.appVersion = appVersion
    }

    public var isFreshInstall: Bool {
        currentSchemaVersion == nil
    }

    public var requiresMigration: Bool {
        guard let currentSchemaVersion else { return true }
        return currentSchemaVersion < targetSchemaVersion
    }
}

public struct AppBootstrapResult {
    public let preparation: AppBootstrapPreparation
    public let migrationReport: MigrationRunReport
    public let environment: AppEnvironment

    public init(
        preparation: AppBootstrapPreparation,
        migrationReport: MigrationRunReport,
        environment: AppEnvironment
    ) {
        self.preparation = preparation
        self.migrationReport = migrationReport
        self.environment = environment
    }
}

public enum AppBootstrapperError: LocalizedError {
    case migrationFailed(
        preparation: AppBootstrapPreparation,
        underlying: Error
    )
    case environmentFailed(
        preparation: AppBootstrapPreparation,
        migrationReport: MigrationRunReport,
        underlying: Error
    )

    public var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return "Veri guncelleme adimi tamamlanamadi."
        case .environmentFailed:
            return "Uygulama ortami hazirlanamadi."
        }
    }

    var stageName: String {
        switch self {
        case .migrationFailed:
            return "migration"
        case .environmentFailed:
            return "environment"
        }
    }

    var underlyingError: Error {
        switch self {
        case .migrationFailed(_, let underlying):
            return underlying
        case .environmentFailed(_, _, let underlying):
            return underlying
        }
    }

    var preparation: AppBootstrapPreparation {
        switch self {
        case .migrationFailed(let preparation, _):
            return preparation
        case .environmentFailed(let preparation, _, _):
            return preparation
        }
    }

    var migrationReport: MigrationRunReport? {
        switch self {
        case .migrationFailed:
            return nil
        case .environmentFailed(_, let report, _):
            return report
        }
    }
}

public final class AppBootstrapper {
    public typealias MigrationExecutor = (_ defaults: UserDefaults, _ bundle: Bundle, _ targetSchemaVersion: Int) throws -> MigrationRunReport
    public typealias EnvironmentBuilder = @MainActor () throws -> AppEnvironment
    public typealias SchemaVersionStoreBuilder = (_ defaults: UserDefaults) -> any SchemaVersionStore

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let targetSchemaVersion: Int
    private let migrationExecutor: MigrationExecutor
    private let environmentBuilder: EnvironmentBuilder
    private let schemaVersionStoreBuilder: SchemaVersionStoreBuilder

    public init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        targetSchemaVersion: Int = LocalSchemaVersion.current.rawValue,
        migrationExecutor: @escaping MigrationExecutor = { defaults, bundle, target in
            try SchemaMigrationBootstrapper.runOnLaunch(
                defaults: defaults,
                bundle: bundle,
                targetSchemaVersion: target
            )
        },
        environmentBuilder: @escaping EnvironmentBuilder = {
            try AppEnvironment.bootstrap()
        },
        schemaVersionStoreBuilder: @escaping SchemaVersionStoreBuilder = { defaults in
            UserDefaultsSchemaVersionStore(defaults: defaults)
        }
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.targetSchemaVersion = targetSchemaVersion
        self.migrationExecutor = migrationExecutor
        self.environmentBuilder = environmentBuilder
        self.schemaVersionStoreBuilder = schemaVersionStoreBuilder
    }

    public func prepare() -> AppBootstrapPreparation {
        let store = schemaVersionStoreBuilder(defaults)
        let appVersionManager = AppVersionManager(bundle: bundle, defaults: defaults)
        return AppBootstrapPreparation(
            currentSchemaVersion: store.currentSchemaVersion(),
            targetSchemaVersion: targetSchemaVersion,
            appVersion: appVersionManager.currentReleaseVersion
        )
    }

    @MainActor
    public func bootstrap(preparation: AppBootstrapPreparation? = nil) throws -> AppBootstrapResult {
        let effectivePreparation = preparation ?? prepare()

        let migrationReport: MigrationRunReport
        do {
            migrationReport = try migrationExecutor(defaults, bundle, targetSchemaVersion)
        } catch {
            throw AppBootstrapperError.migrationFailed(
                preparation: effectivePreparation,
                underlying: error
            )
        }

        let environment: AppEnvironment
        do {
            environment = try environmentBuilder()
        } catch {
            throw AppBootstrapperError.environmentFailed(
                preparation: effectivePreparation,
                migrationReport: migrationReport,
                underlying: error
            )
        }

        return AppBootstrapResult(
            preparation: effectivePreparation,
            migrationReport: migrationReport,
            environment: environment
        )
    }

    public func buildSupportLog(
        error: Error,
        fallbackPreparation: AppBootstrapPreparation? = nil
    ) -> String {
        let bootstrapError = error as? AppBootstrapperError
        let preparation = bootstrapError?.preparation ?? fallbackPreparation ?? prepare()
        let stage = bootstrapError?.stageName ?? "unknown"
        let underlyingError = bootstrapError?.underlyingError ?? error
        let nsError = underlyingError as NSError
        let migrationReport = bootstrapError?.migrationReport

        var lines: [String] = [
            "Voltly Bootstrap Failure",
            "stage=\(stage)",
            "appVersion=\(preparation.appVersion.appVersion)",
            "build=\(preparation.appVersion.buildNumber)",
            "currentSchema=\(preparation.currentSchemaVersion.map(String.init) ?? "nil")",
            "targetSchema=\(preparation.targetSchemaVersion)",
            "errorDomain=\(nsError.domain)",
            "errorCode=\(nsError.code)",
            "errorDescription=\(underlyingError.localizedDescription)"
        ]

        if let migrationReport {
            lines.append("migrationInitializedOnFirstInstall=\(migrationReport.initializedOnFirstInstall)")
            lines.append("appliedMigrations=\(migrationReport.appliedMigrationIdentifiers.joined(separator: ","))")
            lines.append("migrationWarnings=\(migrationReport.warnings.map(\.code).joined(separator: ","))")
            lines.append("backupResult=\(migrationReport.backupResult?.rawValue ?? "none")")
            if let metadata = migrationReport.backupMetadata {
                lines.append("backupID=\(metadata.backupID)")
                lines.append("backupVersion=\(metadata.backupVersion)")
                lines.append("backupDate=\(metadata.createdAt.timeIntervalSince1970)")
                lines.append("backupFile=\(metadata.filePath)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

public struct LaunchFailureState {
    public let title: String
    public let message: String
    public let supportLog: String

    public init(title: String, message: String, supportLog: String) {
        self.title = title
        self.message = message
        self.supportLog = supportLog
    }
}

public struct LaunchSupportLogSheet: Identifiable {
    public let id = UUID()
    public let title: String
    public let logText: String

    public init(title: String, logText: String) {
        self.title = title
        self.logText = logText
    }
}

public enum LaunchBootstrapState {
    case checking(message: String)
    case migrating(message: String)
    case ready(environment: AppEnvironment)
    case failed(LaunchFailureState)
}

@MainActor
public final class LaunchCoordinator: ObservableObject {
    @Published public private(set) var state: LaunchBootstrapState
    @Published public var supportLogSheet: LaunchSupportLogSheet?

    private let bootstrapper: AppBootstrapper
    private var hasStarted = false
    private var isRunning = false

    public init(bootstrapper: AppBootstrapper = AppBootstrapper()) {
        self.bootstrapper = bootstrapper
        state = .checking(message: "Sürüm kontrolü yapılıyor...")
    }

    public func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        runBootstrap()
    }

    public func retry() {
        supportLogSheet = nil
        hasStarted = false
        runBootstrap()
        hasStarted = true
    }

    public func presentSupportLogIfAvailable() {
        guard case .failed(let failure) = state else { return }
        supportLogSheet = LaunchSupportLogSheet(
            title: "Teknik Detaylar",
            logText: failure.supportLog
        )
    }

    private func runBootstrap() {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let preparation = bootstrapper.prepare()
        state = .checking(message: "Sürüm kontrolü yapılıyor...")

        if preparation.requiresMigration {
            state = .migrating(
                message: preparation.isFreshInstall
                    ? "Uygulama hazırlanıyor..."
                    : "Veriler yeni sürüme hazırlanıyor..."
            )
        }

        do {
            let result = try bootstrapper.bootstrap(preparation: preparation)
            state = .ready(environment: result.environment)

            #if DEBUG
            if result.migrationReport.initializedOnFirstInstall {
                print("[Voltly] Local schema initialized at v\(result.migrationReport.targetSchemaVersion).")
            } else if !result.migrationReport.appliedMigrationIdentifiers.isEmpty {
                print("[Voltly] Applied schema migrations: \(result.migrationReport.appliedMigrationIdentifiers.joined(separator: ", "))")
            }
            #endif
        } catch {
            let supportLog = bootstrapper.buildSupportLog(
                error: error,
                fallbackPreparation: preparation
            )
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            state = .failed(
                LaunchFailureState(
                    title: "Voltly başlatılamadı",
                    message: message,
                    supportLog: supportLog
                )
            )
        }
    }
}
