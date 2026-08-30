#if canImport(XCTest)
import XCTest
@testable import Voltly

final class FeatureFlagStoreTests: XCTestCase {
    func testAccessCheckerUsesDefaultValuesWhenOverrideMissing() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        let checker = FeatureAccessChecker(store: store)

        XCTAssertEqual(checker.isEnabled(.advancedInsights), true)
        XCTAssertEqual(checker.isEnabled(.savingsBankV2), false)
        XCTAssertEqual(checker.source(for: .advancedInsights), .defaultValue)
    }

    func testStoreOverrideTakesPrecedence() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        store.setValue(false, for: .smartRecommendations)
        let checker = FeatureAccessChecker(store: store)

        XCTAssertEqual(checker.isEnabled(.smartRecommendations), false)
        XCTAssertEqual(checker.source(for: .smartRecommendations), .stored)
    }

    func testBootstrapDefaultsMergesLegacyAndPreservesUnknownKeys() throws {
        let defaults = try makeDefaults()
        defaults.set(
            [
                "insights.micro.enabled": false,
                "custom.experiment.keep": true
            ],
            forKey: FeatureFlagConstants.storageKey
        )

        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        store.bootstrapDefaultsIfNeeded()
        let values = store.allValues()

        XCTAssertEqual(values["custom.experiment.keep"], true)
        XCTAssertEqual(values["insights.micro.enabled"], false)
        XCTAssertEqual(values[AppFeature.advancedInsights.key], false)
        XCTAssertEqual(values[AppFeature.smartRecommendations.key], false)
        XCTAssertEqual(values[AppFeature.exportPDF.key], false)
    }

    func testResetToDefaultsSetsAllFeatureValues() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        store.setValue(true, for: .betaDashboardCards)
        store.setValue(true, for: .exportPDF)

        store.resetToDefaults()
        let values = store.allValues()

        for feature in AppFeature.allCases {
            XCTAssertEqual(values[feature.key], feature.defaultValue)
        }
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "FeatureFlagStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
