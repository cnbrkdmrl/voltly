import SwiftUI

@MainActor
public final class MigrationDebugViewModel: ObservableObject {
    @Published public private(set) var appVersion = "-"
    @Published public private(set) var appBuild = "-"
    @Published public private(set) var currentSchemaVersion: Int?
    @Published public private(set) var targetSchemaVersion = LocalSchemaVersion.current.rawValue
    @Published public private(set) var lastSuccessfulMigrationVersion: Int?
    @Published public private(set) var lastMigrationDate: Date?
    @Published public private(set) var lastError: MigrationStoredError?
    @Published public private(set) var backupState = MigrationBackupState()
    @Published public private(set) var migrationHistory: [MigrationHistoryEntry] = []
    @Published public private(set) var logEntries: [MigrationLogEntry] = []
    @Published public private(set) var featureStates: [AppFeatureState] = []
    @Published public private(set) var actionMessage: String?

    private let environment: AppEnvironment
    private let defaults: UserDefaults
    private let schemaStore: any SchemaVersionStore
    private let logStore: any MigrationLogStore
    private let backupManager: LocalBackupManager
    private let appVersionManager: AppVersionManager

    public init(
        environment: AppEnvironment,
        defaults: UserDefaults = .standard
    ) {
        self.environment = environment
        self.defaults = defaults
        schemaStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        logStore = UserDefaultsMigrationLogStore(defaults: defaults)
        backupManager = LocalBackupManager(defaults: defaults)
        appVersionManager = AppVersionManager(bundle: .main, defaults: defaults)
        refresh()
    }

    public func refresh() {
        let release = appVersionManager.currentReleaseVersion
        appVersion = release.appVersion
        appBuild = release.buildNumber
        currentSchemaVersion = schemaStore.currentSchemaVersion()
        targetSchemaVersion = LocalSchemaVersion.current.rawValue
        lastSuccessfulMigrationVersion = schemaStore.lastSuccessfulMigrationVersion()
        lastMigrationDate = schemaStore.lastMigrationDate()
        lastError = logStore.lastError()
        backupState = backupManager.state()
        migrationHistory = logStore.history(limit: 120)
        logEntries = logStore.logs(limit: 120)
        featureStates = environment.featureAccessChecker
            .allFeatureStates()
            .sorted { $0.feature.debugTitle < $1.feature.debugTitle }
    }

    public func runFakeMigration() {
        actionMessage = nil

        let simulatedFrom = max(currentSchemaVersion ?? 1, 1)
        let simulatedTo = simulatedFrom + 1
        let fakeSchemaStore = EphemeralSchemaVersionStore(initialVersion: simulatedFrom)
        let context = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )

        do {
            let registry = try MigrationRegistry(
                migrations: [
                    DebugFakeMigration(
                        fromVersion: simulatedFrom,
                        toVersion: simulatedTo
                    )
                ]
            )

            let runner = MigrationRunner(
                schemaVersionStore: fakeSchemaStore,
                migrationRegistry: registry,
                migrationContext: context,
                appVersionManager: appVersionManager,
                backupService: backupManager,
                migrationLogStore: logStore,
                logger: CompositeMigrationLogger(
                    loggers: [
                        DefaultMigrationLogger(),
                        MigrationLogStoreLogger(store: logStore)
                    ]
                )
            )

            _ = try runner.runMigrationsIfNeeded(targetSchemaVersion: simulatedTo)
            actionMessage = "Fake migration başarıyla simüle edildi."
        } catch {
            actionMessage = "Fake migration hatası: \(error.localizedDescription)"
            logStore.setLastError(
                MigrationStoredError(
                    message: error.localizedDescription,
                    createdAt: Date()
                )
            )
        }

        refresh()
    }

    public func simulateMigrationReset() {
        actionMessage = nil
        let current = schemaStore.currentSchemaVersion() ?? targetSchemaVersion
        let resetTo = max(1, current - 1)
        schemaStore.setCurrentSchemaVersion(resetTo)

        logStore.appendLog(
            MigrationLogEntry(
                createdAt: Date(),
                level: .warning,
                message: "Migration reset simülasyonu uygulandı.",
                metadata: [
                    "fromSchema": String(current),
                    "toSchema": String(resetTo)
                ]
            )
        )
        actionMessage = "Schema sürümü v\(resetTo) olarak simüle edildi."
        refresh()
    }

    public func clearLogs() {
        logStore.clearAll()
        actionMessage = "Migration logları temizlendi."
        refresh()
    }

    public func createTestBackup() {
        actionMessage = nil
        let fromVersion = schemaStore.currentSchemaVersion() ?? targetSchemaVersion
        let context = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )

        let plan: [any Migration] = [
            DebugFakeMigration(
                fromVersion: fromVersion,
                toVersion: max(fromVersion + 1, targetSchemaVersion)
            )
        ]

        do {
            let metadata = try backupManager.createSnapshot(
                plan: plan,
                fromVersion: fromVersion,
                targetVersion: targetSchemaVersion,
                context: context
            )
            backupManager.recordResult(.success, metadata: metadata)
            logStore.appendLog(
                MigrationLogEntry(
                    createdAt: Date(),
                    level: .info,
                    message: "Test migration backup oluşturuldu.",
                    metadata: [
                        "backupID": metadata.backupID,
                        "filePath": metadata.filePath
                    ]
                )
            )
            actionMessage = "Test backup hazır: \(metadata.backupID)"
        } catch {
            backupManager.recordResult(.failed, metadata: nil)
            logStore.setLastError(
                MigrationStoredError(
                    message: error.localizedDescription,
                    createdAt: Date()
                )
            )
            logStore.appendLog(
                MigrationLogEntry(
                    createdAt: Date(),
                    level: .error,
                    message: "Test backup oluşturulamadı.",
                    metadata: ["reason": error.localizedDescription]
                )
            )
            actionMessage = "Test backup hatası: \(error.localizedDescription)"
        }

        refresh()
    }
}

public struct MigrationDebugView: View {
    @StateObject private var viewModel: MigrationDebugViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    public init(viewModel: MigrationDebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            if let actionMessage = viewModel.actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.subheadline)
                }
            }

            Section("App version") {
                LabeledContent("Version", value: viewModel.appVersion)
                LabeledContent("Build", value: viewModel.appBuild)
            }

            Section("Schema version") {
                LabeledContent("Current", value: "v\(viewModel.currentSchemaVersion ?? 0)")
                LabeledContent("Target", value: "v\(viewModel.targetSchemaVersion)")
                LabeledContent("Last successful", value: "v\(viewModel.lastSuccessfulMigrationVersion ?? 0)")
                LabeledContent("Last migration date") {
                    if let date = viewModel.lastMigrationDate {
                        Text(Self.dateFormatter.string(from: date))
                    } else {
                        Text("-")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Migration history") {
                if viewModel.migrationHistory.isEmpty {
                    Text("Henüz migration kaydı yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.migrationHistory.prefix(30)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.migrationName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(statusText(entry.status))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor(entry.status))
                            }
                            Text("\(entry.migrationID) • v\(entry.fromVersion)→v\(entry.toVersion) • \(entry.durationMs) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Self.dateFormatter.string(from: entry.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let errorMessage = entry.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Last error") {
                if let lastError = viewModel.lastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lastError.message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Text(Self.dateFormatter.string(from: lastError.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Kayıtlı migration hatası yok.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Feature flags") {
                ForEach(viewModel.featureStates) { state in
                    HStack {
                        Text(state.feature.debugTitle)
                        Spacer()
                        Text(state.isEnabled ? "Açık" : "Kapalı")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(state.isEnabled ? .green : .secondary)
                    }
                }
            }

            Section("Backup state") {
                LabeledContent("Last backup date") {
                    if let date = viewModel.backupState.lastBackupDate {
                        Text(Self.dateFormatter.string(from: date))
                    } else {
                        Text("-")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Backup version", value: viewModel.backupState.backupVersion.map { "v\($0)" } ?? "-")
                LabeledContent("Backup result", value: viewModel.backupState.backupResult?.rawValue ?? "-")
            }

            Section("Test actions") {
                Button("Fake migration çalıştır") {
                    viewModel.runFakeMigration()
                }
                Button("Migration reset simülasyonu") {
                    viewModel.simulateMigrationReset()
                }
                Button("Logs temizle") {
                    viewModel.clearLogs()
                }
                Button("Test backup oluştur") {
                    viewModel.createTestBackup()
                }
            }

            Section("Raw logs") {
                if viewModel.logEntries.isEmpty {
                    Text("Log kaydı yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.logEntries.prefix(40)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.level.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(colorForLevel(entry.level))
                                Spacer()
                                Text(Self.dateFormatter.string(from: entry.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.caption)
                            if !entry.metadata.isEmpty {
                                Text(
                                    entry.metadata
                                        .sorted(by: { $0.key < $1.key })
                                        .map { "\($0.key)=\($0.value)" }
                                        .joined(separator: " ")
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Migration Debug")
        .onAppear {
            viewModel.refresh()
        }
    }

    private func statusText(_ status: MigrationHistoryStatus) -> String {
        switch status {
        case .success:
            return "Başarılı"
        case .failed:
            return "Hata"
        case .skipped:
            return "Atlandı"
        }
    }

    private func statusColor(_ status: MigrationHistoryStatus) -> Color {
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .secondary
        }
    }

    private func colorForLevel(_ level: MigrationLogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private final class EphemeralSchemaVersionStore: SchemaVersionStore {
    private var version: Int?
    private var installDate: Date?
    private var migrationVersion: Int?
    private var migrationDate: Date?

    init(initialVersion: Int?) {
        version = initialVersion
    }

    func currentSchemaVersion() -> Int? { version }
    func setCurrentSchemaVersion(_ version: Int) { self.version = version }
    func isFreshInstall() -> Bool { version == nil }
    func firstInstallDate() -> Date? { installDate }
    func lastSuccessfulMigrationVersion() -> Int? { migrationVersion }
    func lastMigrationDate() -> Date? { migrationDate }

    func markFreshInstall(defaultSchemaVersion: Int, at date: Date) {
        version = defaultSchemaVersion
        installDate = date
        migrationVersion = defaultSchemaVersion
        migrationDate = date
    }

    func recordSuccessfulMigration(to version: Int, at date: Date) {
        self.version = version
        installDate = installDate ?? date
        migrationVersion = version
        migrationDate = date
    }
}

private struct DebugFakeMigration: Migration {
    let id: String
    let name: String
    let fromVersion: Int
    let toVersion: Int
    let isRequired: Bool = true
    let requiresBackup: Bool = false

    init(fromVersion: Int, toVersion: Int) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        id = "debug.fake.migration.v\(fromVersion)_to_v\(toVersion)"
        name = "Fake migration v\(fromVersion) -> v\(toVersion)"
    }

    func run(context: MigrationContext) throws {}
}

#if DEBUG
struct MigrationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MigrationDebugView(
                viewModel: MigrationDebugViewModel(
                    environment: try! AppEnvironment.live(inMemory: true)
                )
            )
        }
    }
}
#endif
