import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

extension VehicleRecord: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }
}

extension ChargingSessionRecord: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }
}

private struct SettingsSyncCandidate: SyncCandidate {
    let id: UUID
    let syncMetadata: SyncMetadata
}

public final class ImportService: ImportServiceProtocol {
    private let context: ModelContext
    private let backupBuilder: JSONBackupBuilder
    private let validator: BackupValidator
    private let mergeEngine: BackupMergeEngine
    private let fileManager: FileManager
    private let vehicleCatalog: ReferenceVehicleCatalogProviding

    private let appSettingsKey = "fuel_baseline"

    public init(
        context: ModelContext,
        backupBuilder: JSONBackupBuilder = JSONBackupBuilder(),
        validator: BackupValidator = BackupValidator(),
        mergeEngine: BackupMergeEngine = BackupMergeEngine(),
        fileManager: FileManager = .default,
        vehicleCatalog: ReferenceVehicleCatalogProviding = StaticReferenceVehicleCatalog()
    ) {
        self.context = context
        self.backupBuilder = backupBuilder
        self.validator = validator
        self.mergeEngine = mergeEngine
        self.fileManager = fileManager
        self.vehicleCatalog = vehicleCatalog
    }

    public func importArchive(from fileURL: URL) throws -> BackupImportResult {
        let data = try readArchiveData(from: fileURL)

        let archive = try validator.decodeAndValidate(from: data)
        var result = BackupImportResult()
        validator.duplicateIdentifierWarnings(in: archive).forEach { result.appendWarning($0) }

        let vehicleDTOs = deduplicatedRecords(
            archive.vehicles,
            label: "vehicles",
            result: &result
        )
        let sessionDTOs = deduplicatedRecords(
            archive.chargingSessions,
            label: "chargingSessions",
            result: &result
        )

        let localVehicles = dictionaryByID(try context.fetch(FetchDescriptor<VehicleRecord>()))
        let localSessions = dictionaryByID(try context.fetch(FetchDescriptor<ChargingSessionRecord>()))

        for dto in vehicleDTOs {
            let decision = mergeEngine.decide(local: localVehicles[dto.id], incoming: dto)
            switch decision {
            case .inserted:
                if dto.isDeleted {
                    result.append(.skipped(reason: "Silinmis arac kaydi eklenmedi."))
                    continue
                }
                context.insert(backupBuilder.appVehicleRecord(from: dto))
                result.append(.inserted)

            case .updated:
                if let local = localVehicles[dto.id] {
                    if dto.isDeleted {
                        context.delete(local)
                    } else {
                        backupBuilder.apply(dto: dto, toAppVehicleRecord: local)
                    }
                    result.append(.updated)
                } else if dto.isDeleted {
                    result.append(.skipped(reason: "Silinmis arac kaydi yerelde bulunmadigi icin atlandi."))
                } else {
                    context.insert(backupBuilder.appVehicleRecord(from: dto))
                    result.append(.inserted)
                }

            case .skipped(let reason):
                result.append(.skipped(reason: reason))
            case .failed(let reason):
                result.append(.failed(reason: reason))
            }
        }

        for dto in sessionDTOs {
            let decision = mergeEngine.decide(local: localSessions[dto.id], incoming: dto)
            switch decision {
            case .inserted:
                if dto.isDeleted {
                    result.append(.skipped(reason: "Silinmis sarj kaydi eklenmedi."))
                    continue
                }
                context.insert(backupBuilder.appChargingSessionRecord(from: dto))
                result.append(.inserted)

            case .updated:
                if let local = localSessions[dto.id] {
                    if dto.isDeleted {
                        context.delete(local)
                    } else {
                        backupBuilder.apply(dto: dto, toAppChargingSessionRecord: local)
                    }
                    result.append(.updated)
                } else if dto.isDeleted {
                    result.append(.skipped(reason: "Silinmis sarj kaydi yerelde bulunmadigi icin atlandi."))
                } else {
                    context.insert(backupBuilder.appChargingSessionRecord(from: dto))
                    result.append(.inserted)
                }

            case .skipped(let reason):
                result.append(.skipped(reason: reason))
            case .failed(let reason):
                result.append(.failed(reason: reason))
            }
        }

        // V1 ana veri modelinde tarifeler icin ayri tablo olmadigi icin bilgi amacli atlanir.
        if !archive.tariffPresets.isEmpty {
            archive.tariffPresets.forEach { _ in
                result.append(.skipped(reason: "Tarife kaydi bu surumde ice aktarmada uygulanmiyor."))
            }
            result.appendWarning("Tarife presetleri bu surumde yerel modele yazilmadi.")
        }

        let localSettingsRecord = try appSettingsRecord()
        let localPreferencesCandidate = localSettingsRecord.map { _ in
            SettingsSyncCandidate(
                id: archive.userPreferences.id,
                syncMetadata: SyncMetadata(
                    updatedAt: .distantPast,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            )
        }

        let preferencesDecision = mergeEngine.decide(local: localPreferencesCandidate, incoming: archive.userPreferences)
        switch preferencesDecision {
        case .inserted, .updated:
            upsertAppSettings(from: archive.userPreferences, existing: localSettingsRecord)
            result.append(localSettingsRecord == nil ? .inserted : .updated)
        case .skipped(let reason):
            result.append(.skipped(reason: reason))
        case .failed(let reason):
            result.append(.failed(reason: reason))
        }

        enrichImportedVehiclesFromCatalogIfNeeded()
        try normalizeVehiclesAfterImport(result: &result)

        if context.hasChanges {
            try context.save()
        }

        return result
    }

    private func readArchiveData(from fileURL: URL) throws -> Data {
        let didAccessSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            if isFileNotFoundError(error) {
                throw BackupValidationError.fileNotFound(fileURL)
            }
            throw BackupValidationError.unreadableFile(fileURL)
        }
    }

    private func isFileNotFoundError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain, nsError.code == ENOENT {
            return true
        }

        return false
    }

    private func upsertAppSettings(from dto: UserPreferencesBackupDTO, existing: AppSettingsRecord?) {
        let fallbackFuelPrice = existing?.fuelPricePerLiter ?? AppConstants.defaultFuelPricePerLiter
        let fallbackICEConsumption = existing?.iceConsumptionLPer100Km ?? AppConstants.defaultICEConsumptionLPer100Km
        let fallbackElectricityPrice = existing?.electricityPricePerKWh ?? AppConstants.defaultElectricityPricePerKWh

        let record = existing ?? AppSettingsRecord(
            key: appSettingsKey,
            fuelPricePerLiter: dto.fuelPricePerLiter ?? fallbackFuelPrice,
            iceConsumptionLPer100Km: dto.iceConsumptionLPer100Km ?? fallbackICEConsumption,
            currencyCode: dto.selectedCurrencyCode,
            electricityPricePerKWh: dto.electricityPricePerKWh ?? fallbackElectricityPrice
        )

        record.currencyCode = dto.selectedCurrencyCode
        record.fuelPricePerLiter = dto.fuelPricePerLiter ?? fallbackFuelPrice
        record.iceConsumptionLPer100Km = dto.iceConsumptionLPer100Km ?? fallbackICEConsumption
        record.electricityPricePerKWh = dto.electricityPricePerKWh ?? fallbackElectricityPrice

        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func appSettingsRecord() throws -> AppSettingsRecord? {
        let descriptor = FetchDescriptor<AppSettingsRecord>()
        let records = try context.fetch(descriptor)
        return records.first(where: { $0.key == appSettingsKey }) ?? records.first
    }

    private func dictionaryByID<T>(_ records: [T]) -> [UUID: T] where T: SyncCandidate {
        var dictionary: [UUID: T] = [:]

        for record in records where dictionary[record.id] == nil {
            dictionary[record.id] = record
        }

        return dictionary
    }

    private func deduplicatedRecords<T>(
        _ records: [T],
        label: String,
        result: inout BackupImportResult
    ) -> [T] where T: SyncCandidate {
        var bestRecords: [UUID: T] = [:]

        for record in records {
            guard let existing = bestRecords[record.id] else {
                bestRecords[record.id] = record
                continue
            }

            if record.syncMetadata.updatedAt > existing.syncMetadata.updatedAt {
                bestRecords[record.id] = record
                result.skippedCount += 1
                result.appendWarning("\(label): \(record.id.uuidString) icin eski duplicate kayit atlandi.")
            } else {
                result.skippedCount += 1
                result.appendWarning("\(label): \(record.id.uuidString) icin duplicate kayit atlandi.")
            }
        }

        return bestRecords.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func enrichImportedVehiclesFromCatalogIfNeeded() {
        guard let vehicles = try? context.fetch(FetchDescriptor<VehicleRecord>()) else {
            return
        }

        for vehicle in vehicles {
            guard needsCatalogEnrichment(vehicle) else { continue }
            guard let reference = bestReferenceSpec(for: vehicle) else { continue }

            if vehicle.enginePowerHP == nil {
                vehicle.enginePowerHP = reference.enginePowerHP
            }
            if vehicle.enginePowerKW == nil {
                vehicle.enginePowerKW = reference.enginePowerKW
            }
            if vehicle.acMaxChargingKW == nil {
                vehicle.acMaxChargingKW = reference.acMaxChargingKW
            }
            if vehicle.dcMaxChargingKW == nil {
                vehicle.dcMaxChargingKW = reference.dcMaxChargingKW
            }
            if vehicle.batteryCapacityKWh <= 0 {
                vehicle.batteryCapacityKWh = reference.batteryCapacityKWh
            }
            if vehicle.factoryConsumptionKWh100km == nil {
                vehicle.factoryConsumptionKWh100km = reference.factoryConsumptionKWh100km
            }
            if vehicle.silhouetteKey == nil {
                vehicle.silhouetteKey = reference.silhouetteKey
            }
            if vehicle.year <= 0 {
                vehicle.year = reference.year
            }
            vehicle.updatedAt = .now
        }
    }

    private func needsCatalogEnrichment(_ vehicle: VehicleRecord) -> Bool {
        vehicle.factoryConsumptionKWh100km == nil ||
        vehicle.enginePowerHP == nil ||
        vehicle.enginePowerKW == nil ||
        vehicle.acMaxChargingKW == nil ||
        vehicle.dcMaxChargingKW == nil ||
        vehicle.silhouetteKey == nil ||
        vehicle.batteryCapacityKWh <= 0
    }

    private func bestReferenceSpec(for vehicle: VehicleRecord) -> ReferenceVehicleSpec? {
        if let exact = vehicleCatalog.find(brand: vehicle.brand, model: vehicle.model, year: vehicle.year) {
            return exact
        }

        let candidates = vehicleCatalog.all().filter {
            $0.brand.caseInsensitiveCompare(vehicle.brand) == .orderedSame &&
            $0.model.caseInsensitiveCompare(vehicle.model) == .orderedSame
        }

        guard !candidates.isEmpty else { return nil }

        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs.year - vehicle.year)
            let rhsDistance = abs(rhs.year - vehicle.year)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.year > rhs.year
        }
    }

    private func normalizeVehiclesAfterImport(result: inout BackupImportResult) throws {
        let allSessions = try context.fetch(FetchDescriptor<ChargingSessionRecord>())
        var allVehicles = try context.fetch(FetchDescriptor<VehicleRecord>())

        let existingVehicleIDs = Set(allVehicles.map(\.id))
        let missingVehicleIDs = Set(allSessions.map(\.vehicleID)).subtracting(existingVehicleIDs)

        if !missingVehicleIDs.isEmpty {
            let now = Date()
            let defaultYear = Calendar(identifier: .gregorian).component(.year, from: now)

            for vehicleID in missingVehicleIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                let placeholder = VehicleRecord(
                    id: vehicleID,
                    brand: "İçe Aktarılan",
                    model: "Araç",
                    year: defaultYear,
                    enginePowerHP: nil,
                    enginePowerKW: nil,
                    acMaxChargingKW: nil,
                    dcMaxChargingKW: nil,
                    batteryCapacityKWh: 0,
                    factoryConsumptionKWh100km: nil,
                    colorCode: nil,
                    silhouetteKey: nil,
                    isActive: false,
                    createdAt: now,
                    updatedAt: now
                )
                context.insert(placeholder)
            }

            result.appendWarning("Bazı şarj kayıtlarında araç bilgisi eksikti. Eksik araçlar otomatik oluşturuldu.")
            allVehicles = try context.fetch(FetchDescriptor<VehicleRecord>())
        }

        guard !allVehicles.isEmpty else { return }

        let sessionCountByVehicle = Dictionary(
            allSessions.map { ($0.vehicleID, 1) },
            uniquingKeysWith: +
        )
        let activeVehicles = allVehicles.filter(\.isActive)
        if activeVehicles.count == 1, let currentActiveVehicle = activeVehicles.first {
            let currentActiveSessionCount = sessionCountByVehicle[currentActiveVehicle.id, default: 0]
            let hasAnotherVehicleWithSessions = allVehicles.contains {
                $0.id != currentActiveVehicle.id && sessionCountByVehicle[$0.id, default: 0] > 0
            }

            guard currentActiveSessionCount == 0, hasAnotherVehicleWithSessions else {
                return
            }

            let preferredActiveID = preferredActiveVehicleID(
                vehicles: allVehicles,
                sessions: allSessions
            )

            guard preferredActiveID != currentActiveVehicle.id else {
                return
            }

            setActiveVehicle(id: preferredActiveID, in: allVehicles)
            result.appendWarning("Aktif araçta kayıt bulunamadı. İçe aktarılan veriye sahip araç otomatik aktif seçildi.")
            return
        }

        let preferredActiveID = preferredActiveVehicleID(
            vehicles: allVehicles,
            sessions: allSessions
        )

        setActiveVehicle(id: preferredActiveID, in: allVehicles)

        if activeVehicles.isEmpty {
            result.appendWarning("İçe aktarımdan sonra aktif araç bulunamadı. Bir araç otomatik aktif seçildi.")
        } else {
            result.appendWarning("Birden fazla aktif araç bulundu. Tek aktif araç olacak şekilde düzeltildi.")
        }
    }

    private func preferredActiveVehicleID(
        vehicles: [VehicleRecord],
        sessions: [ChargingSessionRecord]
    ) -> UUID {
        var sessionCountByVehicle: [UUID: Int] = [:]
        var latestSessionDateByVehicle: [UUID: Date] = [:]

        for session in sessions {
            sessionCountByVehicle[session.vehicleID, default: 0] += 1
            let latest = latestSessionDateByVehicle[session.vehicleID] ?? .distantPast
            if session.sessionDate > latest {
                latestSessionDateByVehicle[session.vehicleID] = session.sessionDate
            }
        }

        return vehicles.max { lhs, rhs in
            let lhsCount = sessionCountByVehicle[lhs.id, default: 0]
            let rhsCount = sessionCountByVehicle[rhs.id, default: 0]
            if lhsCount != rhsCount {
                return lhsCount < rhsCount
            }

            let lhsLatestDate = latestSessionDateByVehicle[lhs.id] ?? lhs.updatedAt
            let rhsLatestDate = latestSessionDateByVehicle[rhs.id] ?? rhs.updatedAt
            if lhsLatestDate != rhsLatestDate {
                return lhsLatestDate < rhsLatestDate
            }

            return lhs.updatedAt < rhs.updatedAt
        }?.id ?? vehicles[0].id
    }

    private func setActiveVehicle(id: UUID, in vehicles: [VehicleRecord]) {
        let now = Date()
        for vehicle in vehicles {
            vehicle.isActive = (vehicle.id == id)
            vehicle.updatedAt = now
        }
    }
}
#endif
