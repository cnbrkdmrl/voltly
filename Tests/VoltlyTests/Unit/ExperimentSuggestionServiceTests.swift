#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ExperimentSuggestionServiceTests: XCTestCase {
    private let service = ExperimentSuggestionService()

    func testMakeReportSuggestsReduceDCForSpeedFocusedProfile() {
        let report = makeReport(
            sessionCount: 12,
            homeRatio: 10,
            acRatio: 15,
            dcRatio: 75,
            averageStartSOC: 18,
            averageEndSOC: 86
        )
        let profile = makeProfile(type: .speedFocused, sessionCount: 12)

        let result = service.makeReport(
            report: report,
            profile: profile,
            sessions: []
        )

        XCTAssertEqual(result?.suggestion.type, .reduceDC)
        XCTAssertEqual(result?.suggestion.suggestedChargeType, .ac)
        XCTAssertTrue(result?.suggestion.message.contains("DC payın") == true)
    }

    func testMakeReportBuildsSavingsResultWhenACShareImprovesWeekOverWeek() {
        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23
        let vehicleID = UUID()
        let vehicle = Vehicle(
            id: vehicleID,
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        let sessions: [ChargingSession] = [
            // Previous week
            makeSession(referenceDate: referenceDate, daysAgo: 12, vehicleID: vehicleID, method: .home, price: 90, energy: 15),
            makeSession(referenceDate: referenceDate, daysAgo: 11, vehicleID: vehicleID, method: .publicDC, price: 420, energy: 25),
            makeSession(referenceDate: referenceDate, daysAgo: 10, vehicleID: vehicleID, method: .home, price: 90, energy: 15),
            makeSession(referenceDate: referenceDate, daysAgo: 9, vehicleID: vehicleID, method: .publicDC, price: 420, energy: 25),
            // Recent week
            makeSession(referenceDate: referenceDate, daysAgo: 5, vehicleID: vehicleID, method: .home, price: 90, energy: 15),
            makeSession(referenceDate: referenceDate, daysAgo: 4, vehicleID: vehicleID, method: .publicAC, price: 220, energy: 22),
            makeSession(referenceDate: referenceDate, daysAgo: 2, vehicleID: vehicleID, method: .home, price: 90, energy: 15),
            makeSession(referenceDate: referenceDate, daysAgo: 1, vehicleID: vehicleID, method: .publicDC, price: 360, energy: 25)
        ]

        let report = ChargeInsightService().analyze(
            vehicle: vehicle,
            sessions: sessions,
            referenceDate: referenceDate
        )
        let profile = UserChargingProfileService().makeProfile(
            report: report,
            referenceDate: referenceDate
        )

        let result = service.makeReport(
            report: report,
            profile: profile,
            sessions: sessions,
            referenceDate: referenceDate
        )

        XCTAssertEqual(result?.suggestion.type, .increaseAC)
        XCTAssertEqual(result?.resultInsight?.type, .increaseAC)
        XCTAssertTrue(result?.resultInsight?.message.contains("AC ağırlığını artırarak") == true)
    }

    func testMakeReportReturnsNilWhenSessionCountIsInsufficient() {
        let report = makeReport(
            sessionCount: 5,
            homeRatio: 20,
            acRatio: 30,
            dcRatio: 50,
            averageStartSOC: 24,
            averageEndSOC: 78
        )

        XCTAssertNil(
            service.makeReport(
                report: report,
                profile: nil,
                sessions: []
            )
        )
    }

    private func makeProfile(
        type: UserChargingProfileType,
        sessionCount: Int
    ) -> UserChargingProfileReport {
        UserChargingProfileReport(
            type: type,
            headline: type.titleTR,
            description: "Test profile",
            ratioSummary: "Ev %20 • AC %20 • DC %60",
            confidence: DataConfidenceScore(
                score: 88,
                source: .real,
                sampleCount: sessionCount,
                exactSampleCount: sessionCount,
                estimatedSampleCount: 0,
                missingSampleCount: 0
            ),
            sessionCount: sessionCount,
            generatedAt: Date(timeIntervalSince1970: 1_774_699_200)
        )
    }

    private func makeReport(
        sessionCount: Int,
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double,
        averageStartSOC: Double,
        averageEndSOC: Double
    ) -> ChargeInsightReport {
        let confidence = DataConfidenceScore(
            score: 90,
            source: .real,
            sampleCount: max(sessionCount, 1),
            exactSampleCount: max(sessionCount, 1),
            estimatedSampleCount: 0,
            missingSampleCount: 0
        )

        let usageRatios = ChargeInsightUsageRatios(
            homeRatio: InsightMetric(value: homeRatio, confidence: confidence),
            acRatio: InsightMetric(value: acRatio, confidence: confidence),
            dcRatio: InsightMetric(value: dcRatio, confidence: confidence)
        )

        let summary = ChargeInsightWindowSummary(
            sessionCount: sessionCount,
            averageStartSOC: InsightMetric(value: averageStartSOC, confidence: confidence),
            averageEndSOC: InsightMetric(value: averageEndSOC, confidence: confidence),
            averageEnergyKWh: InsightMetric(value: 24, confidence: confidence),
            averageDurationMinutes: InsightMetric(value: 48, confidence: confidence),
            averageTLPerKWh: InsightMetric(value: 11.8, confidence: confidence),
            averageTLPer100Km: InsightMetric(value: 220, confidence: confidence)
        )

        let delta = ChargeInsightWindowDelta(
            averageStartSOCDelta: InsightMetric(value: 0, confidence: confidence),
            averageEndSOCDelta: InsightMetric(value: 0, confidence: confidence),
            averageEnergyKWhDelta: InsightMetric(value: 0, confidence: confidence),
            averageDurationMinutesDelta: InsightMetric(value: 0, confidence: confidence),
            averageTLPerKWhDelta: InsightMetric(value: 0, confidence: confidence),
            averageTLPer100KmDelta: InsightMetric(value: 0, confidence: confidence)
        )

        return ChargeInsightReport(
            generatedAt: Date(timeIntervalSince1970: 1_774_699_200),
            currencyCode: "TRY",
            overall: summary,
            lastFiveSessions: summary,
            lastThirtyDays: summary,
            previousThirtyDays: summary,
            previousThirtyDayDelta: delta,
            usageRatios: usageRatios,
            actionInsights: []
        )
    }

    private func makeSession(
        referenceDate: Date,
        daysAgo: Int,
        vehicleID: UUID,
        method: ChargeMethod,
        price: Double,
        energy: Double
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: vehicleID,
            sessionDate: referenceDate.addingTimeInterval(TimeInterval(-daysAgo * 24 * 60 * 60)),
            chargeMethod: method,
            stationBrand: method == .home ? "Ev" : "ZES",
            locationName: method == .home ? "Ev" : "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: method == .publicDC ? 18 : 24,
            socEnd: method == .publicDC ? 84 : 78,
            isFullCharge: false,
            durationMin: method == .publicDC ? 34 : 55,
            odometerKM: 10_000 + Double(daysAgo * 20)
        )
    }
}
#endif
