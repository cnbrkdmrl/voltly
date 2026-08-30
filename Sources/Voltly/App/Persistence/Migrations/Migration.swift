import Foundation

public struct MigrationContext {
    public let userDefaults: UserDefaults
    public let appVersionManager: AppVersionManager

    public init(
        userDefaults: UserDefaults = .standard,
        appVersionManager: AppVersionManager
    ) {
        self.userDefaults = userDefaults
        self.appVersionManager = appVersionManager
    }
}

public protocol Migration {
    var id: String { get }
    var name: String { get }
    var fromVersion: Int { get }
    var toVersion: Int { get }
    var isRequired: Bool { get }
    var requiresBackup: Bool { get }

    func run(context: MigrationContext) throws
}

public extension Migration {
    var isRequired: Bool { true }
    var requiresBackup: Bool { false }
}
