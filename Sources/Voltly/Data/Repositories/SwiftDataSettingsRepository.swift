import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public final class SwiftDataSettingsRepository: SettingsRepository {
    private let context: ModelContext
    private let storageKey = "fuel_baseline"

    public init(context: ModelContext) {
        self.context = context
    }

    public func getFuelBaseline() throws -> FuelBaselineSettings {
        if let record = try findRecord() {
            return FuelBaselineSettings(
                fuelPricePerLiter: record.fuelPricePerLiter,
                iceConsumptionLPer100Km: record.iceConsumptionLPer100Km,
                currencyCode: record.currencyCode,
                electricityPricePerKWh: record.electricityPricePerKWh
            )
        }

        let defaults = FuelBaselineSettings(
            fuelPricePerLiter: AppConstants.defaultFuelPricePerLiter,
            iceConsumptionLPer100Km: AppConstants.defaultICEConsumptionLPer100Km,
            currencyCode: AppConstants.defaultCurrencyCode,
            electricityPricePerKWh: AppConstants.defaultElectricityPricePerKWh
        )
        try saveFuelBaseline(defaults)
        return defaults
    }

    public func saveFuelBaseline(_ settings: FuelBaselineSettings) throws {
        let record = try findRecord() ?? AppSettingsRecord(
            key: storageKey,
            fuelPricePerLiter: settings.fuelPricePerLiter,
            iceConsumptionLPer100Km: settings.iceConsumptionLPer100Km,
            currencyCode: settings.currencyCode,
            electricityPricePerKWh: settings.electricityPricePerKWh
        )

        record.fuelPricePerLiter = settings.fuelPricePerLiter
        record.iceConsumptionLPer100Km = settings.iceConsumptionLPer100Km
        record.currencyCode = settings.currencyCode
        record.electricityPricePerKWh = settings.electricityPricePerKWh

        if record.modelContext == nil {
            context.insert(record)
        }

        try context.save()
    }

    private func findRecord() throws -> AppSettingsRecord? {
        let descriptor = FetchDescriptor<AppSettingsRecord>()
        return try context.fetch(descriptor).first(where: { $0.key == storageKey })
    }
}
#endif
