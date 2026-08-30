#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ConfidenceScoreEngineTests: XCTestCase {
    private let engine = ConfidenceScoreEngine()

    func testEvaluateReturnsHighForDenseReliableData() {
        let confidence = engine.evaluate(
            ConfidenceScoreInput(
                sampleCount: 12,
                dataConfidence: DataConfidenceScore(
                    score: 88,
                    source: .real,
                    sampleCount: 12,
                    exactSampleCount: 10,
                    estimatedSampleCount: 2,
                    missingSampleCount: 0
                ),
                hasCostData: true,
                hasDistanceData: true
            )
        )

        XCTAssertEqual(confidence, .high)
    }

    func testEvaluateReturnsLowForSparseEstimatedData() {
        let confidence = engine.evaluate(
            ConfidenceScoreInput(
                sampleCount: 2,
                dataConfidence: DataConfidenceScore(
                    score: 32,
                    source: .estimated,
                    sampleCount: 2,
                    exactSampleCount: 0,
                    estimatedSampleCount: 2,
                    missingSampleCount: 0
                ),
                hasCostData: false,
                hasDistanceData: false
            )
        )

        XCTAssertEqual(confidence, .low)
    }
}
#endif
