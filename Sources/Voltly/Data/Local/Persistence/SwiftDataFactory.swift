import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public enum SwiftDataFactory {
    public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            VehicleRecord.self,
            ChargingSessionRecord.self,
            AppSettingsRecord.self,
            ConsumptionBlockRecord.self,
            VehicleMetricSnapshotRecord.self
        ])
        if !inMemory {
            try ensureApplicationSupportDirectoryExists()
        }
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: configuration)
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
#endif
