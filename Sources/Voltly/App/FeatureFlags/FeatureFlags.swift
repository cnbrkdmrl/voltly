import Foundation

public protocol FeatureFlag {
    var key: String { get }
    var defaultValue: Bool { get }
}

public enum AppFeature: String, CaseIterable, Identifiable, Sendable, FeatureFlag {
    case savingsBankV2 = "feature.savings_bank_v2.enabled"
    case smartRecommendations = "feature.smart_recommendations.enabled"
    case advancedInsights = "feature.advanced_insights.enabled"
    case exportPDF = "feature.export_pdf.enabled"
    case betaDashboardCards = "feature.beta_dashboard_cards.enabled"

    public var id: String { key }
    public var key: String { rawValue }

    public var defaultValue: Bool {
        switch self {
        case .savingsBankV2:
            return false
        case .smartRecommendations:
            return true
        case .advancedInsights:
            return true
        case .exportPDF:
            return false
        case .betaDashboardCards:
            return false
        }
    }

    public var debugTitle: String {
        switch self {
        case .savingsBankV2:
            return "Savings Bank V2"
        case .smartRecommendations:
            return "Smart Recommendations"
        case .advancedInsights:
            return "Advanced Insights"
        case .exportPDF:
            return "Export PDF"
        case .betaDashboardCards:
            return "Beta Dashboard Cards"
        }
    }

    public var debugDescription: String {
        switch self {
        case .savingsBankV2:
            return "Tasarruf ekranindaki V2 kumbarasi/ozet modullerini aktif eder."
        case .smartRecommendations:
            return "Mikro icgoru, trend kirilimi ve akilli form onerilerini kontrol eder."
        case .advancedInsights:
            return "Analiz ekranindaki detayli davranis ve istasyon icgorulerini aktif eder."
        case .exportPDF:
            return "Aylik ozetin PDF disa aktarim altyapisini acar."
        case .betaDashboardCards:
            return "Dashboard icin beta kartlarini gorunur hale getirir."
        }
    }
}

public enum FeatureFlagConstants {
    public static let storageKey = "settings.features.toggles.v1"
}

public enum FeatureValueSource: Equatable, Sendable {
    case stored
    case defaultValue
}

public struct AppFeatureState: Identifiable, Equatable, Sendable {
    public var id: String { feature.id }
    public let feature: AppFeature
    public let isEnabled: Bool
    public let source: FeatureValueSource

    public init(
        feature: AppFeature,
        isEnabled: Bool,
        source: FeatureValueSource
    ) {
        self.feature = feature
        self.isEnabled = isEnabled
        self.source = source
    }
}

public enum FeatureFlagDefaultConfiguration {
    public static let legacyKeyMapping: [AppFeature: [String]] = [
        .advancedInsights: [
            "insights.micro.enabled",
            "insights.trend_break.enabled"
        ],
        .smartRecommendations: [
            "charge.smart_repeat.enabled",
            "insights.micro.enabled"
        ]
    ]

    public static func defaultValue(for feature: AppFeature) -> Bool {
        feature.defaultValue
    }

    /// Returns a normalized feature dictionary using:
    /// 1) existing explicit AppFeature key
    /// 2) compatible legacy key
    /// 3) AppFeature default value
    public static func mergedFeatureDictionary(
        existingRaw: [String: Any]
    ) -> [String: Bool] {
        var normalized = existingRaw.reduce(into: [String: Bool]()) { partial, item in
            if let value = item.value as? Bool {
                partial[item.key] = value
            }
        }

        for feature in AppFeature.allCases {
            if normalized[feature.key] != nil {
                continue
            }

            if let resolvedLegacyValue = resolveLegacyValue(
                for: feature,
                from: normalized
            ) {
                normalized[feature.key] = resolvedLegacyValue
                continue
            }

            normalized[feature.key] = feature.defaultValue
        }

        return normalized
    }

    private static func resolveLegacyValue(
        for feature: AppFeature,
        from dictionary: [String: Bool]
    ) -> Bool? {
        guard let legacyKeys = legacyKeyMapping[feature] else { return nil }
        for key in legacyKeys {
            if let value = dictionary[key] {
                return value
            }
        }
        return nil
    }
}

public protocol FeatureFlagStore {
    func value(for feature: AppFeature) -> Bool?
    func setValue(_ value: Bool, for feature: AppFeature)
    func removeValue(for feature: AppFeature)
    func allValues() -> [String: Bool]
    func bootstrapDefaultsIfNeeded()
    func resetToDefaults()
}

public final class UserDefaultsFeatureFlagStore: FeatureFlagStore {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = FeatureFlagConstants.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func value(for feature: AppFeature) -> Bool? {
        allValues()[feature.key]
    }

    public func setValue(_ value: Bool, for feature: AppFeature) {
        mutateStore { dictionary in
            dictionary[feature.key] = value
        }
    }

    public func removeValue(for feature: AppFeature) {
        mutateStore { dictionary in
            dictionary.removeValue(forKey: feature.key)
        }
    }

    public func allValues() -> [String: Bool] {
        guard let raw = defaults.dictionary(forKey: storageKey) else {
            return [:]
        }
        return raw.reduce(into: [String: Bool]()) { partial, item in
            if let value = item.value as? Bool {
                partial[item.key] = value
            }
        }
    }

    public func bootstrapDefaultsIfNeeded() {
        let existingRaw = defaults.dictionary(forKey: storageKey) ?? [:]
        let merged = FeatureFlagDefaultConfiguration.mergedFeatureDictionary(
            existingRaw: existingRaw
        )
        let existingBool = allValues()

        guard existingBool != merged else {
            return
        }

        defaults.set(merged, forKey: storageKey)
    }

    public func resetToDefaults() {
        let defaultsMap = Dictionary(
            uniqueKeysWithValues: AppFeature.allCases.map {
                ($0.key, $0.defaultValue)
            }
        )
        defaults.set(defaultsMap, forKey: storageKey)
    }

    private func mutateStore(_ mutate: (inout [String: Bool]) -> Void) {
        var dictionary = allValues()
        mutate(&dictionary)
        defaults.set(dictionary, forKey: storageKey)
    }
}

public protocol FeatureAccessChecking {
    func isEnabled(_ feature: AppFeature) -> Bool
    func source(for feature: AppFeature) -> FeatureValueSource
    func allFeatureStates() -> [AppFeatureState]
}

public final class FeatureAccessChecker: FeatureAccessChecking {
    private let store: any FeatureFlagStore

    public init(
        store: any FeatureFlagStore,
        bootstrapDefaults: Bool = false
    ) {
        self.store = store
        if bootstrapDefaults {
            store.bootstrapDefaultsIfNeeded()
        }
    }

    public func isEnabled(_ feature: AppFeature) -> Bool {
        store.value(for: feature) ?? feature.defaultValue
    }

    public func source(for feature: AppFeature) -> FeatureValueSource {
        store.value(for: feature) == nil ? .defaultValue : .stored
    }

    public func allFeatureStates() -> [AppFeatureState] {
        AppFeature.allCases.map { feature in
            AppFeatureState(
                feature: feature,
                isEnabled: isEnabled(feature),
                source: source(for: feature)
            )
        }
    }
}
