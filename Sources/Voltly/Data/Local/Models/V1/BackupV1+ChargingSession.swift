import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

extension BackupV1 {
    @Model
    public final class ChargingSession {
        @Attribute(.unique) public var id: UUID
        public var vehicleId: UUID
        public var date: Date
        public var stationName: String?
        public var operatorName: String?
        public var chargerType: ChargerType
        public var startSoc: Double?
        public var endSoc: Double?
        public var energyKWh: Double?
        public var durationMinutes: Int?
        public var totalPrice: Double?
        public var currencyCode: String
        public var odometerKm: Double?
        public var note: String?
        public var createdAt: Date
        public var updatedAt: Date
        public var schemaVersion: Int
        public var isDeleted: Bool

        public init(
            id: UUID = UUID(),
            vehicleId: UUID,
            date: Date,
            stationName: String? = nil,
            operatorName: String? = nil,
            chargerType: ChargerType,
            startSoc: Double? = nil,
            endSoc: Double? = nil,
            energyKWh: Double? = nil,
            durationMinutes: Int? = nil,
            totalPrice: Double? = nil,
            currencyCode: String = AppCurrencyCode.turkishLira.rawValue,
            odometerKm: Double? = nil,
            note: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            schemaVersion: Int = AppSchemaVersion.current.rawValue,
            isDeleted: Bool = false
        ) {
            self.id = id
            self.vehicleId = vehicleId
            self.date = date
            self.stationName = stationName
            self.operatorName = operatorName
            self.chargerType = chargerType
            self.startSoc = startSoc
            self.endSoc = endSoc
            self.energyKWh = energyKWh
            self.durationMinutes = durationMinutes
            self.totalPrice = totalPrice
            self.currencyCode = currencyCode
            self.odometerKm = odometerKm
            self.note = note
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.schemaVersion = schemaVersion
            self.isDeleted = isDeleted
        }
    }
}
#endif
