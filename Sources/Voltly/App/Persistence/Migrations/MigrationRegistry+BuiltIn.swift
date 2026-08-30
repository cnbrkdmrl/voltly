import Foundation

public struct MigrateChargeDraftNoteFieldV1ToV2: Migration {
    private enum Keys {
        static let note = "note"
        static let notes = "notes"
    }

    public let id = "migration.v1_to_v2.add_charge_draft_note_field"
    public let name = "Charge taslagina note alani ekleme"
    public let fromVersion = LocalSchemaVersion.v1.rawValue
    public let toVersion = LocalSchemaVersion.v2.rawValue
    public let isRequired = true

    public init() {}

    public func run(context: MigrationContext) throws {
        guard var draft = BuiltInMigrationDraftStore.loadDraft(from: context.userDefaults) else {
            return
        }

        guard draft[Keys.notes] == nil else { return }

        if let legacyNote = draft[Keys.note] as? String {
            draft[Keys.notes] = legacyNote
        } else {
            draft[Keys.notes] = ""
        }
        try BuiltInMigrationDraftStore.saveDraft(draft, to: context.userDefaults)
    }
}

public struct MigrateChargeDraftStationNameOptionalV2ToV3: Migration {
    private enum Keys {
        static let stationLegacy = "station"
        static let stationName = "stationName"
        static let stationBrand = "stationBrand"
    }

    public let id = "migration.v2_to_v3.add_station_name_optional"
    public let name = "Charge taslagina opsiyonel stationName alani ekleme"
    public let fromVersion = LocalSchemaVersion.v2.rawValue
    public let toVersion = LocalSchemaVersion.v3.rawValue
    public let isRequired = true

    public init() {}

    public func run(context: MigrationContext) throws {
        guard var draft = BuiltInMigrationDraftStore.loadDraft(from: context.userDefaults) else {
            return
        }

        var hasMutation = false

        if draft[Keys.stationName] == nil {
            if let station = Self.validString(draft[Keys.stationLegacy]) ?? Self.validString(draft[Keys.stationBrand]) {
                draft[Keys.stationName] = station
                hasMutation = true
            }
        }

        if draft[Keys.stationBrand] == nil,
           let stationName = Self.validString(draft[Keys.stationName]) {
            draft[Keys.stationBrand] = stationName
            hasMutation = true
        }

        guard hasMutation else { return }
        try BuiltInMigrationDraftStore.saveDraft(draft, to: context.userDefaults)
    }

    private static func validString(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct MigrateLegacyChargeTypeToEnumV3ToV4: Migration {
    private enum Keys {
        static let legacyChargeType = "chargeType"
        static let chargeMethodRaw = "chargeMethodRaw"
    }

    public let id = "migration.v3_to_v4.convert_charge_type_to_enum"
    public let name = "Legacy chargeType string alanini enum raw degere donusturme"
    public let fromVersion = LocalSchemaVersion.v3.rawValue
    public let toVersion = LocalSchemaVersion.v4.rawValue
    public let isRequired = true
    public let requiresBackup = true

    public init() {}

    public func run(context: MigrationContext) throws {
        guard var draft = BuiltInMigrationDraftStore.loadDraft(from: context.userDefaults) else {
            return
        }

        let sourceRaw = (draft[Keys.legacyChargeType] as? String)
            ?? (draft[Keys.chargeMethodRaw] as? String)
        guard let sourceRaw else { return }

        let normalized = Self.normalizeChargeMethodRaw(sourceRaw)
        var hasMutation = false

        if draft[Keys.chargeMethodRaw] as? String != normalized {
            draft[Keys.chargeMethodRaw] = normalized
            hasMutation = true
        }

        if draft[Keys.legacyChargeType] != nil {
            draft.removeValue(forKey: Keys.legacyChargeType)
            hasMutation = true
        }

        guard hasMutation else { return }
        try BuiltInMigrationDraftStore.saveDraft(draft, to: context.userDefaults)
    }

    private static func normalizeChargeMethodRaw(_ rawValue: String) -> String {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        switch normalized {
        case "home", "ev", "house":
            return ChargeMethod.home.rawValue
        case "ac", "publicac", "public_ac":
            return ChargeMethod.publicAC.rawValue
        case "dc", "publicdc", "public_dc":
            return ChargeMethod.publicDC.rawValue
        default:
            // Unknown legacy values are safely downgraded to home.
            return ChargeMethod.home.rawValue
        }
    }
}

public struct MigrateSettingsFeatureTogglesV4ToV5: Migration {
    private enum Keys {
        static let featureToggles = FeatureFlagConstants.storageKey
    }

    private enum Defaults {
        static let toggles: [String: Bool] = [
            "insights.micro.enabled": true,
            "insights.trend_break.enabled": true,
            "charge.smart_repeat.enabled": true
        ]
    }

    public let id = "migration.v4_to_v5.bootstrap_feature_toggles"
    public let name = "Settings feature toggle alanlarini varsayilanlarla baslatma"
    public let fromVersion = LocalSchemaVersion.v4.rawValue
    public let toVersion = LocalSchemaVersion.v5.rawValue
    public let isRequired = true

    public init() {}

    public func run(context: MigrationContext) throws {
        let defaults = context.userDefaults
        let existingRaw = defaults.dictionary(forKey: Keys.featureToggles) ?? [:]

        var merged = existingRaw
        for (key, value) in Defaults.toggles where merged[key] == nil {
            merged[key] = value
        }

        guard !NSDictionary(dictionary: existingRaw).isEqual(to: merged) else {
            return
        }

        defaults.set(merged, forKey: Keys.featureToggles)
    }
}

public struct MigrateAppFeatureFlagsV5ToV6: Migration {
    private enum Keys {
        static let featureToggles = FeatureFlagConstants.storageKey
    }

    public let id = "migration.v5_to_v6.migrate_app_feature_flags"
    public let name = "Feature flag anahtarlarini yeni app feature setiyle hizalama"
    public let fromVersion = LocalSchemaVersion.v5.rawValue
    public let toVersion = LocalSchemaVersion.v6.rawValue
    public let isRequired = true

    public init() {}

    public func run(context: MigrationContext) throws {
        let defaults = context.userDefaults
        let existingRaw = defaults.dictionary(forKey: Keys.featureToggles) ?? [:]
        let merged = FeatureFlagDefaultConfiguration.mergedFeatureDictionary(
            existingRaw: existingRaw
        )

        let existingBool = existingRaw.reduce(into: [String: Bool]()) { partial, item in
            if let value = item.value as? Bool {
                partial[item.key] = value
            }
        }

        guard existingBool != merged else { return }
        defaults.set(merged, forKey: Keys.featureToggles)
    }
}

public extension MigrationRegistry {
    static func makeDefault() throws -> MigrationRegistry {
        try MigrationRegistry(
            migrations: [
                MigrateChargeDraftNoteFieldV1ToV2(),
                MigrateChargeDraftStationNameOptionalV2ToV3(),
                MigrateLegacyChargeTypeToEnumV3ToV4(),
                MigrateSettingsFeatureTogglesV4ToV5(),
                MigrateAppFeatureFlagsV5ToV6()
            ]
        )
    }
}

private enum BuiltInMigrationDraftStore {
    private static let draftKey = "add_charge.draft"

    static func loadDraft(from defaults: UserDefaults) -> [String: Any]? {
        guard let data = defaults.data(forKey: draftKey) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    static func saveDraft(_ draft: [String: Any], to defaults: UserDefaults) throws {
        let data = try JSONSerialization.data(withJSONObject: draft, options: [])
        defaults.set(data, forKey: draftKey)
    }
}

public enum SchemaMigrationBootstrapper {
    @discardableResult
    public static func runOnLaunch(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        targetSchemaVersion: Int = LocalSchemaVersion.current.rawValue
    ) throws -> MigrationRunReport {
        let migrationLogStore = UserDefaultsMigrationLogStore(defaults: defaults)
        let appVersionManager = AppVersionManager(bundle: bundle, defaults: defaults)
        let schemaVersionStore = UserDefaultsSchemaVersionStore(defaults: defaults)
        let migrationRegistry = try MigrationRegistry.makeDefault()
        let migrationContext = MigrationContext(
            userDefaults: defaults,
            appVersionManager: appVersionManager
        )
        let logger = CompositeMigrationLogger(
            loggers: [
                DefaultMigrationLogger(),
                MigrationLogStoreLogger(store: migrationLogStore)
            ]
        )
        let runner = MigrationRunner(
            schemaVersionStore: schemaVersionStore,
            migrationRegistry: migrationRegistry,
            migrationContext: migrationContext,
            appVersionManager: appVersionManager,
            backupService: LocalBackupManager(defaults: defaults),
            migrationLogStore: migrationLogStore,
            logger: logger
        )
        return try runner.runMigrationsIfNeeded(targetSchemaVersion: targetSchemaVersion)
    }
}
