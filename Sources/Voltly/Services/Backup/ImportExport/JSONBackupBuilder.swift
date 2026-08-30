import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData
#endif

public struct JSONBackupBuilder {
    public typealias AppVersionProvider = () -> String
    public typealias DateProvider = () -> Date

    private let appVersionProvider: AppVersionProvider
    private let dateProvider: DateProvider

    public init(
        appVersionProvider: @escaping AppVersionProvider = JSONBackupBuilder.defaultAppVersion,
        dateProvider: @escaping DateProvider = Date.init
    ) {
        self.appVersionProvider = appVersionProvider
        self.dateProvider = dateProvider
    }

    public func makeArchive(
        vehicles: [VehicleBackupDTO],
        chargingSessions: [ChargingSessionBackupDTO],
        tariffPresets: [TariffPresetBackupDTO],
        userPreferences: UserPreferencesBackupDTO
    ) -> BackupArchiveDTO {
        BackupArchiveDTO(
            schemaVersion: AppSchemaVersion.current.rawValue,
            exportedAt: dateProvider(),
            appVersion: appVersionProvider(),
            vehicles: vehicles.sorted { $0.id.uuidString < $1.id.uuidString },
            chargingSessions: chargingSessions.sorted { $0.id.uuidString < $1.id.uuidString },
            tariffPresets: tariffPresets.sorted { $0.id.uuidString < $1.id.uuidString },
            userPreferences: userPreferences
        )
    }

    public func encode(_ archive: BackupArchiveDTO) throws -> Data {
        let encoder = JSONBackupBuilder.makeEncoder()
        return try encoder.encode(archive)
    }

    public func decode(_ data: Data) throws -> BackupArchiveDTO {
        let decoder = JSONBackupBuilder.makeDecoder()
        return try decoder.decode(BackupArchiveDTO.self, from: data)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func defaultAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (.some(version), .some(build)) where !version.isEmpty && !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        default:
            return "unknown"
        }
    }
}

#if VOLTLY_ENABLE_SWIFTDATA
extension JSONBackupBuilder {
    public func appVehicleDTO(from model: VehicleRecord) -> VehicleBackupDTO {
        VehicleBackupDTO(
            id: model.id,
            brand: model.brand,
            model: model.model,
            versionName: nil,
            year: model.year,
            enginePowerHP: model.enginePowerHP,
            enginePowerKW: model.enginePowerKW,
            acMaxChargingKW: model.acMaxChargingKW,
            dcMaxChargingKW: model.dcMaxChargingKW,
            batteryCapacityKWh: model.batteryCapacityKWh,
            factoryConsumptionKWh100km: model.factoryConsumptionKWh100km,
            colorCode: model.colorCode,
            silhouetteKey: model.silhouetteKey,
            isActive: model.isActive,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    public func appChargingSessionDTO(from model: ChargingSessionRecord) -> ChargingSessionBackupDTO {
        ChargingSessionBackupDTO(
            id: model.id,
            vehicleId: model.vehicleID,
            date: model.sessionDate,
            stationName: model.locationName,
            operatorName: model.stationBrand,
            chargerType: chargerType(from: model.chargeMethodRaw),
            startSoc: model.socStart,
            endSoc: model.socEnd,
            energyKWh: model.energyKWh,
            durationMinutes: model.durationMin,
            totalPrice: model.priceTotal,
            currencyCode: model.currencyCode,
            odometerKm: model.odometerKM,
            contextTags: decodeContextTags(from: model.contextTagsRaw).map(\.rawValue),
            note: model.notes,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    public func appUserPreferencesDTO(from settings: AppSettingsRecord?) -> UserPreferencesBackupDTO {
        guard let settings else {
            return .default(now: dateProvider())
        }

        let now = dateProvider()
        return UserPreferencesBackupDTO(
            id: UserPreferencesBackupDTO.defaultIdentifier,
            selectedCurrencyCode: settings.currencyCode,
            fuelPricePerLiter: settings.fuelPricePerLiter,
            iceConsumptionLPer100Km: settings.iceConsumptionLPer100Km,
            electricityPricePerKWh: settings.electricityPricePerKWh,
            distanceUnit: .km,
            energyUnit: .kilowattHour,
            defaultChargerType: nil,
            includeOdometerInForms: true,
            createdAt: now,
            updatedAt: now,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    public func appVehicleRecord(from dto: VehicleBackupDTO) -> VehicleRecord {
        VehicleRecord(
            id: dto.id,
            brand: dto.brand,
            model: dto.model,
            year: dto.year ?? inferredYear(from: dto.createdAt),
            enginePowerHP: dto.enginePowerHP,
            enginePowerKW: dto.enginePowerKW,
            acMaxChargingKW: dto.acMaxChargingKW,
            dcMaxChargingKW: dto.dcMaxChargingKW,
            batteryCapacityKWh: dto.batteryCapacityKWh ?? 0,
            factoryConsumptionKWh100km: dto.factoryConsumptionKWh100km,
            colorCode: dto.colorCode,
            silhouetteKey: dto.silhouetteKey,
            isActive: dto.isActive ?? false,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    public func appChargingSessionRecord(from dto: ChargingSessionBackupDTO) -> ChargingSessionRecord {
        let startSoc = dto.startSoc ?? 0
        let endSoc = dto.endSoc ?? startSoc

        return ChargingSessionRecord(
            id: dto.id,
            vehicleID: dto.vehicleId,
            sessionDate: dto.date,
            chargeMethodRaw: chargeMethodRaw(from: dto.chargerType),
            stationBrand: dto.operatorName,
            locationName: dto.stationName,
            priceTotal: dto.totalPrice ?? 0,
            currencyCode: dto.currencyCode,
            energyKWh: dto.energyKWh,
            energyIsEstimated: false,
            socStart: startSoc,
            socEnd: endSoc,
            isFullCharge: endSoc >= 99.5,
            durationMin: dto.durationMinutes,
            odometerKM: dto.odometerKm,
            outsideTempC: nil,
            weatherCondition: nil,
            rangeGainedKmEstimate: nil,
            contextTagsRaw: encodeContextTags(dto.contextTags),
            notes: dto.note,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    public func apply(dto: VehicleBackupDTO, toAppVehicleRecord model: VehicleRecord) {
        model.brand = dto.brand
        model.model = dto.model
        if let year = dto.year {
            model.year = year
        }
        model.enginePowerHP = dto.enginePowerHP ?? model.enginePowerHP
        model.enginePowerKW = dto.enginePowerKW ?? model.enginePowerKW
        model.acMaxChargingKW = dto.acMaxChargingKW ?? model.acMaxChargingKW
        model.dcMaxChargingKW = dto.dcMaxChargingKW ?? model.dcMaxChargingKW
        model.batteryCapacityKWh = dto.batteryCapacityKWh ?? model.batteryCapacityKWh
        model.factoryConsumptionKWh100km = dto.factoryConsumptionKWh100km ?? model.factoryConsumptionKWh100km
        model.colorCode = dto.colorCode ?? model.colorCode
        model.silhouetteKey = dto.silhouetteKey ?? model.silhouetteKey
        if let isActive = dto.isActive {
            model.isActive = isActive
        }
        model.updatedAt = dto.updatedAt
    }

    public func apply(dto: ChargingSessionBackupDTO, toAppChargingSessionRecord model: ChargingSessionRecord) {
        let startSoc = dto.startSoc ?? 0
        let endSoc = dto.endSoc ?? startSoc

        model.vehicleID = dto.vehicleId
        model.sessionDate = dto.date
        model.chargeMethodRaw = chargeMethodRaw(from: dto.chargerType)
        model.stationBrand = dto.operatorName
        model.locationName = dto.stationName
        model.priceTotal = dto.totalPrice ?? 0
        model.currencyCode = dto.currencyCode
        model.energyKWh = dto.energyKWh
        model.energyIsEstimated = false
        model.socStart = startSoc
        model.socEnd = endSoc
        model.isFullCharge = endSoc >= 99.5
        model.durationMin = dto.durationMinutes
        model.odometerKM = dto.odometerKm
        model.contextTagsRaw = encodeContextTags(dto.contextTags)
        model.notes = dto.note
        model.updatedAt = dto.updatedAt
    }

    private func inferredYear(from date: Date) -> Int {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        if (2000...2100).contains(year) {
            return year
        }
        return Calendar(identifier: .gregorian).component(.year, from: dateProvider())
    }

    private func chargerType(from chargeMethodRaw: String) -> ChargerType {
        if chargeMethodRaw == ChargeMethod.publicDC.rawValue {
            return .dc
        }
        return .ac
    }

    private func chargeMethodRaw(from chargerType: ChargerType) -> String {
        switch chargerType {
        case .ac:
            return ChargeMethod.publicAC.rawValue
        case .dc:
            return ChargeMethod.publicDC.rawValue
        }
    }

    private func decodeContextTags(from rawValue: String?) -> [ChargeContextTag] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ChargeContextTag].self, from: data) else {
            return []
        }

        return decoded
    }

    private func encodeContextTags(_ rawValues: [String]?) -> String? {
        guard let rawValues else { return nil }

        let tags = rawValues.compactMap(ChargeContextTag.init(rawValue:))
        guard !tags.isEmpty,
              let data = try? JSONEncoder().encode(tags) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

extension JSONBackupBuilder {
    public func makeArchive(
        vehicles: [BackupV1.Vehicle],
        chargingSessions: [BackupV1.ChargingSession],
        tariffPresets: [BackupV1.TariffPreset],
        userPreferences: BackupV1.UserPreferences?
    ) -> BackupArchiveDTO {
        let vehicleDTOs = vehicles.map(vehicleDTO(from:))
        let sessionDTOs = chargingSessions.map(chargingSessionDTO(from:))
        let tariffDTOs = tariffPresets.map(tariffPresetDTO(from:))
        let preferencesDTO = userPreferences.map(userPreferencesDTO(from:)) ?? .default(now: dateProvider())

        return makeArchive(
            vehicles: vehicleDTOs,
            chargingSessions: sessionDTOs,
            tariffPresets: tariffDTOs,
            userPreferences: preferencesDTO
        )
    }

    public func vehicleDTO(from model: BackupV1.Vehicle) -> VehicleBackupDTO {
        VehicleBackupDTO(
            id: model.id,
            brand: model.brand,
            model: model.model,
            versionName: model.versionName,
            year: nil,
            enginePowerHP: nil,
            enginePowerKW: nil,
            acMaxChargingKW: nil,
            dcMaxChargingKW: nil,
            batteryCapacityKWh: model.batteryCapacityKWh,
            factoryConsumptionKWh100km: nil,
            colorCode: nil,
            silhouetteKey: nil,
            isActive: nil,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: model.schemaVersion,
            isDeleted: model.isDeleted
        )
    }

    public func chargingSessionDTO(from model: BackupV1.ChargingSession) -> ChargingSessionBackupDTO {
        ChargingSessionBackupDTO(
            id: model.id,
            vehicleId: model.vehicleId,
            date: model.date,
            stationName: model.stationName,
            operatorName: model.operatorName,
            chargerType: model.chargerType,
            startSoc: model.startSoc,
            endSoc: model.endSoc,
            energyKWh: model.energyKWh,
            durationMinutes: model.durationMinutes,
            totalPrice: model.totalPrice,
            currencyCode: model.currencyCode,
            odometerKm: model.odometerKm,
            note: model.note,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: model.schemaVersion,
            isDeleted: model.isDeleted
        )
    }

    public func tariffPresetDTO(from model: BackupV1.TariffPreset) -> TariffPresetBackupDTO {
        TariffPresetBackupDTO(
            id: model.id,
            title: model.title,
            pricePerKWh: model.pricePerKWh,
            currencyCode: model.currencyCode,
            providerName: model.providerName,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: model.schemaVersion,
            isDeleted: model.isDeleted
        )
    }

    public func userPreferencesDTO(from model: BackupV1.UserPreferences) -> UserPreferencesBackupDTO {
        UserPreferencesBackupDTO(
            id: model.id,
            selectedCurrencyCode: model.selectedCurrencyCode,
            fuelPricePerLiter: nil,
            iceConsumptionLPer100Km: nil,
            electricityPricePerKWh: nil,
            distanceUnit: model.distanceUnit,
            energyUnit: model.energyUnit,
            defaultChargerType: model.defaultChargerType,
            includeOdometerInForms: model.includeOdometerInForms,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: model.schemaVersion,
            isDeleted: model.isDeleted
        )
    }

    public func vehicleModel(from dto: VehicleBackupDTO) -> BackupV1.Vehicle {
        BackupV1.Vehicle(
            id: dto.id,
            brand: dto.brand,
            model: dto.model,
            versionName: dto.versionName,
            batteryCapacityKWh: dto.batteryCapacityKWh,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            schemaVersion: dto.schemaVersion,
            isDeleted: dto.isDeleted
        )
    }

    public func chargingSessionModel(from dto: ChargingSessionBackupDTO) -> BackupV1.ChargingSession {
        BackupV1.ChargingSession(
            id: dto.id,
            vehicleId: dto.vehicleId,
            date: dto.date,
            stationName: dto.stationName,
            operatorName: dto.operatorName,
            chargerType: dto.chargerType,
            startSoc: dto.startSoc,
            endSoc: dto.endSoc,
            energyKWh: dto.energyKWh,
            durationMinutes: dto.durationMinutes,
            totalPrice: dto.totalPrice,
            currencyCode: dto.currencyCode,
            odometerKm: dto.odometerKm,
            note: dto.note,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            schemaVersion: dto.schemaVersion,
            isDeleted: dto.isDeleted
        )
    }

    public func tariffPresetModel(from dto: TariffPresetBackupDTO) -> BackupV1.TariffPreset {
        BackupV1.TariffPreset(
            id: dto.id,
            title: dto.title,
            pricePerKWh: dto.pricePerKWh,
            currencyCode: dto.currencyCode,
            providerName: dto.providerName,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            schemaVersion: dto.schemaVersion,
            isDeleted: dto.isDeleted
        )
    }

    public func userPreferencesModel(from dto: UserPreferencesBackupDTO) -> BackupV1.UserPreferences {
        BackupV1.UserPreferences(
            id: dto.id,
            selectedCurrencyCode: dto.selectedCurrencyCode,
            distanceUnit: dto.distanceUnit,
            energyUnit: dto.energyUnit,
            defaultChargerType: dto.defaultChargerType,
            includeOdometerInForms: dto.includeOdometerInForms,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            schemaVersion: dto.schemaVersion,
            isDeleted: dto.isDeleted
        )
    }

    public func apply(dto: VehicleBackupDTO, to model: BackupV1.Vehicle) {
        model.brand = dto.brand
        model.model = dto.model
        model.versionName = dto.versionName
        model.batteryCapacityKWh = dto.batteryCapacityKWh
        model.createdAt = dto.createdAt
        model.updatedAt = dto.updatedAt
        model.schemaVersion = dto.schemaVersion
        model.isDeleted = dto.isDeleted
    }

    public func apply(dto: ChargingSessionBackupDTO, to model: BackupV1.ChargingSession) {
        model.vehicleId = dto.vehicleId
        model.date = dto.date
        model.stationName = dto.stationName
        model.operatorName = dto.operatorName
        model.chargerType = dto.chargerType
        model.startSoc = dto.startSoc
        model.endSoc = dto.endSoc
        model.energyKWh = dto.energyKWh
        model.durationMinutes = dto.durationMinutes
        model.totalPrice = dto.totalPrice
        model.currencyCode = dto.currencyCode
        model.odometerKm = dto.odometerKm
        model.note = dto.note
        model.createdAt = dto.createdAt
        model.updatedAt = dto.updatedAt
        model.schemaVersion = dto.schemaVersion
        model.isDeleted = dto.isDeleted
    }

    public func apply(dto: TariffPresetBackupDTO, to model: BackupV1.TariffPreset) {
        model.title = dto.title
        model.pricePerKWh = dto.pricePerKWh
        model.currencyCode = dto.currencyCode
        model.providerName = dto.providerName
        model.createdAt = dto.createdAt
        model.updatedAt = dto.updatedAt
        model.schemaVersion = dto.schemaVersion
        model.isDeleted = dto.isDeleted
    }

    public func apply(dto: UserPreferencesBackupDTO, to model: BackupV1.UserPreferences) {
        model.selectedCurrencyCode = dto.selectedCurrencyCode
        model.distanceUnit = dto.distanceUnit
        model.energyUnit = dto.energyUnit
        model.defaultChargerType = dto.defaultChargerType
        model.includeOdometerInForms = dto.includeOdometerInForms
        model.createdAt = dto.createdAt
        model.updatedAt = dto.updatedAt
        model.schemaVersion = dto.schemaVersion
        model.isDeleted = dto.isDeleted
    }
}
#endif
