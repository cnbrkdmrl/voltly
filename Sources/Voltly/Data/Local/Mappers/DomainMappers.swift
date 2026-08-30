import Foundation

#if VOLTLY_ENABLE_SWIFTDATA
public enum DomainMappers {
    public static func map(_ record: VehicleRecord) -> Vehicle {
        Vehicle(
            id: record.id,
            brand: record.brand,
            model: record.model,
            year: record.year,
            enginePowerHP: record.enginePowerHP,
            enginePowerKW: record.enginePowerKW,
            acMaxChargingKW: record.acMaxChargingKW,
            dcMaxChargingKW: record.dcMaxChargingKW,
            batteryCapacityKWh: record.batteryCapacityKWh,
            factoryConsumptionKWh100km: record.factoryConsumptionKWh100km,
            colorCode: record.colorCode,
            silhouetteKey: record.silhouetteKey,
            isActive: record.isActive,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    public static func map(_ record: ChargingSessionRecord) -> ChargingSession {
        ChargingSession(
            id: record.id,
            vehicleID: record.vehicleID,
            sessionDate: record.sessionDate,
            chargeMethod: ChargeMethod(rawValue: record.chargeMethodRaw) ?? .home,
            stationBrand: record.stationBrand,
            locationName: record.locationName,
            priceTotal: record.priceTotal,
            currencyCode: record.currencyCode,
            energyKWh: record.energyKWh,
            energyIsEstimated: record.energyIsEstimated,
            socStart: record.socStart,
            socEnd: record.socEnd,
            isFullCharge: record.isFullCharge,
            durationMin: record.durationMin,
            odometerKM: record.odometerKM,
            outsideTempC: record.outsideTempC,
            weatherCondition: record.weatherCondition,
            rangeGainedKmEstimate: record.rangeGainedKmEstimate,
            contextTags: decodeContextTags(from: record.contextTagsRaw),
            notes: record.notes,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func decodeContextTags(from rawValue: String?) -> [ChargeContextTag] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ChargeContextTag].self, from: data) else {
            return []
        }

        return decoded
    }
}
#endif
