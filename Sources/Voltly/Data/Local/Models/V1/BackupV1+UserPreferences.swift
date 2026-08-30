import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

extension BackupV1 {
    @Model
    public final class UserPreferences {
        @Attribute(.unique) public var id: UUID
        public var selectedCurrencyCode: String
        public var distanceUnit: DistanceUnit
        public var energyUnit: EnergyUnit
        public var defaultChargerType: ChargerType?
        public var includeOdometerInForms: Bool
        public var createdAt: Date
        public var updatedAt: Date
        public var schemaVersion: Int
        public var isDeleted: Bool

        public init(
            id: UUID = UUID(),
            selectedCurrencyCode: String = AppCurrencyCode.turkishLira.rawValue,
            distanceUnit: DistanceUnit = .km,
            energyUnit: EnergyUnit = .kilowattHour,
            defaultChargerType: ChargerType? = nil,
            includeOdometerInForms: Bool = true,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            schemaVersion: Int = AppSchemaVersion.current.rawValue,
            isDeleted: Bool = false
        ) {
            self.id = id
            self.selectedCurrencyCode = selectedCurrencyCode
            self.distanceUnit = distanceUnit
            self.energyUnit = energyUnit
            self.defaultChargerType = defaultChargerType
            self.includeOdometerInForms = includeOdometerInForms
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.schemaVersion = schemaVersion
            self.isDeleted = isDeleted
        }
    }
}
#endif
