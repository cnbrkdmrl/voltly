import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public enum BackupV1Persistence {
    public static var schema: Schema {
        Schema([
            BackupV1.Vehicle.self,
            BackupV1.ChargingSession.self,
            BackupV1.TariffPreset.self,
            BackupV1.UserPreferences.self
        ])
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            try ensureApplicationSupportDirectoryExists()
        }
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    public static func makeContext(inMemory: Bool = false) throws -> ModelContext {
        let container = try makeContainer(inMemory: inMemory)
        return ModelContext(container)
    }

    private static func ensureApplicationSupportDirectoryExists() throws {
        let url = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

public struct BackupV1PersistenceStack {
    public let container: ModelContainer
    public let context: ModelContext

    public init(inMemory: Bool = false) throws {
        let container = try BackupV1Persistence.makeContainer(inMemory: inMemory)
        self.container = container
        self.context = ModelContext(container)
    }
}
#endif
