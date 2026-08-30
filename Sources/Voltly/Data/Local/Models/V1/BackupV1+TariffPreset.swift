import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

extension BackupV1 {
    @Model
    public final class TariffPreset {
        @Attribute(.unique) public var id: UUID
        public var title: String
        public var pricePerKWh: Double
        public var currencyCode: String
        public var providerName: String?
        public var createdAt: Date
        public var updatedAt: Date
        public var schemaVersion: Int
        public var isDeleted: Bool

        public init(
            id: UUID = UUID(),
            title: String,
            pricePerKWh: Double,
            currencyCode: String = AppCurrencyCode.turkishLira.rawValue,
            providerName: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            schemaVersion: Int = AppSchemaVersion.current.rawValue,
            isDeleted: Bool = false
        ) {
            self.id = id
            self.title = title
            self.pricePerKWh = pricePerKWh
            self.currencyCode = currencyCode
            self.providerName = providerName
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.schemaVersion = schemaVersion
            self.isDeleted = isDeleted
        }
    }
}
#endif
