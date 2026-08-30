import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

extension BackupV1 {
    @Model
    public final class Vehicle {
        @Attribute(.unique) public var id: UUID
        public var brand: String
        public var model: String
        public var versionName: String?
        public var batteryCapacityKWh: Double?
        public var createdAt: Date
        public var updatedAt: Date
        public var schemaVersion: Int
        public var isDeleted: Bool

        public init(
            id: UUID = UUID(),
            brand: String,
            model: String,
            versionName: String? = nil,
            batteryCapacityKWh: Double? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            schemaVersion: Int = AppSchemaVersion.current.rawValue,
            isDeleted: Bool = false
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.versionName = versionName
            self.batteryCapacityKWh = batteryCapacityKWh
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.schemaVersion = schemaVersion
            self.isDeleted = isDeleted
        }
    }
}
#endif
