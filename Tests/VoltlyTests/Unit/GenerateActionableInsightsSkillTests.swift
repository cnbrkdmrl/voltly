#if canImport(XCTest)
import XCTest
@testable import Voltly

final class GenerateActionableInsightsSkillTests: XCTestCase {
    private let skill = GenerateActionableInsightsSkill()

    func testGenerateInsightPrefersReduceDCWhenMultipleRulesMatch() {
        let insight = skill.generateInsight(
            input: GenerateActionableInsightsInput(
                dcUsageRatio: 72,
                acUsageRatio: 18,
                homeUsageRatio: 10,
                averageChargeRange: 84
            )
        )

        XCTAssertEqual(insight?.recommendationType, .reduceDC)
        XCTAssertEqual(insight?.suggestedAction.defaultChargeType, .ac)
    }

    func testGenerateInsightSuggestsIncreaseACWhenACUsageIsLow() {
        let insight = skill.generateInsight(
            input: GenerateActionableInsightsInput(
                dcUsageRatio: 40,
                acUsageRatio: 20,
                homeUsageRatio: 40,
                averageChargeRange: 55
            )
        )

        XCTAssertEqual(insight?.recommendationType, .increaseAC)
        XCTAssertEqual(insight?.suggestedAction.defaultChargeType, .ac)
    }

    func testGenerateInsightReturnsNilWhenMetricsAreInsufficient() {
        let insight = skill.generateInsight(
            input: GenerateActionableInsightsInput(
                dcUsageRatio: nil,
                acUsageRatio: nil,
                homeUsageRatio: nil,
                averageChargeRange: nil
            )
        )

        XCTAssertNil(insight)
    }
}
#endif
