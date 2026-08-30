import Foundation

public struct BackupArchiveDTO: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String
    public let vehicles: [VehicleBackupDTO]
    public let chargingSessions: [ChargingSessionBackupDTO]
    public let tariffPresets: [TariffPresetBackupDTO]
    public let userPreferences: UserPreferencesBackupDTO

    public init(
        schemaVersion: Int,
        exportedAt: Date,
        appVersion: String,
        vehicles: [VehicleBackupDTO],
        chargingSessions: [ChargingSessionBackupDTO],
        tariffPresets: [TariffPresetBackupDTO],
        userPreferences: UserPreferencesBackupDTO
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.vehicles = vehicles
        self.chargingSessions = chargingSessions
        self.tariffPresets = tariffPresets
        self.userPreferences = userPreferences
    }
}

public struct VehicleBackupDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let brand: String
    public let model: String
    public let versionName: String?
    public let year: Int?
    public let enginePowerHP: Double?
    public let enginePowerKW: Double?
    public let acMaxChargingKW: Double?
    public let dcMaxChargingKW: Double?
    public let batteryCapacityKWh: Double?
    public let factoryConsumptionKWh100km: Double?
    public let colorCode: String?
    public let silhouetteKey: String?
    public let isActive: Bool?
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int
    public let isDeleted: Bool

    public init(
        id: UUID,
        brand: String,
        model: String,
        versionName: String?,
        year: Int? = nil,
        enginePowerHP: Double? = nil,
        enginePowerKW: Double? = nil,
        acMaxChargingKW: Double? = nil,
        dcMaxChargingKW: Double? = nil,
        batteryCapacityKWh: Double?,
        factoryConsumptionKWh100km: Double? = nil,
        colorCode: String? = nil,
        silhouetteKey: String? = nil,
        isActive: Bool? = nil,
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int,
        isDeleted: Bool
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.versionName = versionName
        self.year = year
        self.enginePowerHP = enginePowerHP
        self.enginePowerKW = enginePowerKW
        self.acMaxChargingKW = acMaxChargingKW
        self.dcMaxChargingKW = dcMaxChargingKW
        self.batteryCapacityKWh = batteryCapacityKWh
        self.factoryConsumptionKWh100km = factoryConsumptionKWh100km
        self.colorCode = colorCode
        self.silhouetteKey = silhouetteKey
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.isDeleted = isDeleted
    }
}

public struct ChargingSessionBackupDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let vehicleId: UUID
    public let date: Date
    public let stationName: String?
    public let operatorName: String?
    public let chargerType: ChargerType
    public let startSoc: Double?
    public let endSoc: Double?
    public let energyKWh: Double?
    public let durationMinutes: Int?
    public let totalPrice: Double?
    public let currencyCode: String
    public let odometerKm: Double?
    public let contextTags: [String]?
    public let note: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int
    public let isDeleted: Bool

    public init(
        id: UUID,
        vehicleId: UUID,
        date: Date,
        stationName: String?,
        operatorName: String?,
        chargerType: ChargerType,
        startSoc: Double?,
        endSoc: Double?,
        energyKWh: Double?,
        durationMinutes: Int?,
        totalPrice: Double?,
        currencyCode: String,
        odometerKm: Double?,
        contextTags: [String]? = nil,
        note: String?,
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int,
        isDeleted: Bool
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
        self.contextTags = contextTags
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.isDeleted = isDeleted
    }
}

public struct TariffPresetBackupDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let pricePerKWh: Double
    public let currencyCode: String
    public let providerName: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int
    public let isDeleted: Bool

    public init(
        id: UUID,
        title: String,
        pricePerKWh: Double,
        currencyCode: String,
        providerName: String?,
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int,
        isDeleted: Bool
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

public struct UserPreferencesBackupDTO: Codable, Equatable, Sendable, Identifiable {
    public static let defaultIdentifier = UUID(uuidString: "9D6E3B42-5718-4E56-91D2-D2BA6F2C5A11")!

    public let id: UUID
    public let selectedCurrencyCode: String
    public let fuelPricePerLiter: Double?
    public let iceConsumptionLPer100Km: Double?
    public let electricityPricePerKWh: Double?
    public let distanceUnit: DistanceUnit
    public let energyUnit: EnergyUnit
    public let defaultChargerType: ChargerType?
    public let includeOdometerInForms: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let schemaVersion: Int
    public let isDeleted: Bool

    public init(
        id: UUID,
        selectedCurrencyCode: String,
        fuelPricePerLiter: Double? = nil,
        iceConsumptionLPer100Km: Double? = nil,
        electricityPricePerKWh: Double? = nil,
        distanceUnit: DistanceUnit,
        energyUnit: EnergyUnit,
        defaultChargerType: ChargerType?,
        includeOdometerInForms: Bool,
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int,
        isDeleted: Bool
    ) {
        self.id = id
        self.selectedCurrencyCode = selectedCurrencyCode
        self.fuelPricePerLiter = fuelPricePerLiter
        self.iceConsumptionLPer100Km = iceConsumptionLPer100Km
        self.electricityPricePerKWh = electricityPricePerKWh
        self.distanceUnit = distanceUnit
        self.energyUnit = energyUnit
        self.defaultChargerType = defaultChargerType
        self.includeOdometerInForms = includeOdometerInForms
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.isDeleted = isDeleted
    }

    public static func `default`(now: Date = Date()) -> UserPreferencesBackupDTO {
        UserPreferencesBackupDTO(
            id: defaultIdentifier,
            selectedCurrencyCode: AppCurrencyCode.turkishLira.rawValue,
            fuelPricePerLiter: AppConstants.defaultFuelPricePerLiter,
            iceConsumptionLPer100Km: AppConstants.defaultICEConsumptionLPer100Km,
            electricityPricePerKWh: AppConstants.defaultElectricityPricePerKWh,
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
}
