#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ChargeContextInsightServiceTests: XCTestCase {
    private let service = ChargeContextInsightService()

    func testGenerateInsightsReturnsLongRoadInsightWhenConsumptionIsHigher() {
        let sessions = [
            makeSession(daysAgo: 9, price: 180, energy: 16, odometer: 1_000, tags: [.cityDriving]),
            makeSession(daysAgo: 8, price: 220, energy: 16, odometer: 1_600, tags: [.cityDriving]),
            makeSession(daysAgo: 7, price: 240, energy: 18, odometer: 2_000, tags: [.longRoad]),
            makeSession(daysAgo: 6, price: 420, energy: 36, odometer: 2_600, tags: [.longRoad]),
            makeSession(daysAgo: 5, price: 430, energy: 42, odometer: 3_200, tags: [.longRoad])
        ]

        let insights = service.generateInsights(from: sessions)

        XCTAssertTrue(insights.contains { $0.id == "context.long_road_consumption" })
    }

    func testGenerateInsightsReturnsColdWeatherCostInsightWhenAverageCostIncreases() {
        let sessions = [
            makeSession(daysAgo: 9, price: 210, energy: 20, odometer: 1_000, tags: [.cityDriving]),
            makeSession(daysAgo: 8, price: 200, energy: 20, odometer: 1_600, tags: [.cityDriving]),
            makeSession(daysAgo: 7, price: 310, energy: 20, odometer: 2_000, tags: [.coldWeather]),
            makeSession(daysAgo: 6, price: 300, energy: 20, odometer: 2_600, tags: [.coldWeather]),
            makeSession(daysAgo: 5, price: 290, energy: 20, odometer: 3_200, tags: [.coldWeather])
        ]

        let insights = service.generateInsights(from: sessions)

        XCTAssertTrue(insights.contains { $0.id == "context.cold_weather_cost" })
    }

    func testGenerateInsightsReturnsEmptyWhenTaggedDataIsInsufficient() {
        let sessions = [
            makeSession(daysAgo: 2, price: 180, energy: 18, odometer: 1_000, tags: [.cityDriving]),
            makeSession(daysAgo: 1, price: 240, energy: 22, odometer: 1_100, tags: [.longRoad]),
            makeSession(daysAgo: 0, price: 260, energy: 24, odometer: 1_200, tags: [.longRoad])
        ]

        XCTAssertTrue(service.generateInsights(from: sessions).isEmpty)
    }

    private func makeSession(
        daysAgo: Int,
        price: Double,
        energy: Double,
        odometer: Double,
        tags: [ChargeContextTag]
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: UUID(),
            sessionDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            chargeMethod: .publicAC,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            isFullCharge: false,
            durationMin: 40,
            odometerKM: odometer,
            contextTags: tags
        )
    }
}
#endif
