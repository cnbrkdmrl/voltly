#if canImport(XCTest)
import XCTest
@testable import Voltly

final class SmartFavoriteStationServiceTests: XCTestCase {
    private let service = SmartFavoriteStationService()
    private let vehicleID = UUID()

    func testMakeReportBuildsMostUsedCheapestAndMostEfficientSuggestions() {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessions: [ChargingSession] = [
            makeSession(referenceDate: referenceDate, minutesAgo: 700, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 360, energy: 30, odometer: 1_000),
            makeSession(referenceDate: referenceDate, minutesAgo: 600, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 330, energy: 28, odometer: 1_100),
            makeSession(referenceDate: referenceDate, minutesAgo: 500, method: .publicDC, brand: "Trugo", location: "Levent", price: 360, energy: 24, odometer: 1_200),
            makeSession(referenceDate: referenceDate, minutesAgo: 400, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 315, energy: 27, odometer: 1_300),
            makeSession(referenceDate: referenceDate, minutesAgo: 300, method: .publicAC, brand: "Eşarj", location: "Maslak", price: 180, energy: 20, odometer: 1_420),
            makeSession(referenceDate: referenceDate, minutesAgo: 200, method: .publicAC, brand: "Eşarj", location: "Maslak", price: 184, energy: 20, odometer: 1_540),
            makeSession(referenceDate: referenceDate, minutesAgo: 100, method: .publicDC, brand: "Trugo", location: "Levent", price: 352, energy: 22, odometer: 1_640),
            makeSession(referenceDate: referenceDate, minutesAgo: 50, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 312, energy: 26, odometer: 1_740)
        ]

        let report = service.makeReport(sessions: sessions)

        XCTAssertEqual(report?.suggestions.map(\.category), [.mostUsed, .cheapest, .mostEfficient])

        guard let mostUsed = report?.suggestions.first(where: { $0.category == .mostUsed }) else {
            return XCTFail("mostUsed önerisi bekleniyordu")
        }
        XCTAssertEqual(mostUsed.displayName, "ZES • Kadikoy")
        XCTAssertEqual(mostUsed.suggestedChargeMethod, .publicAC)
        XCTAssertEqual(mostUsed.sessionCount, 4)

        guard let cheapest = report?.suggestions.first(where: { $0.category == .cheapest }) else {
            return XCTFail("cheapest önerisi bekleniyordu")
        }
        XCTAssertEqual(cheapest.displayName, "Eşarj • Maslak")
        XCTAssertEqual(cheapest.averageTLPerKWh ?? 0, 9.1, accuracy: 0.01)

        guard let mostEfficient = report?.suggestions.first(where: { $0.category == .mostEfficient }) else {
            return XCTFail("mostEfficient önerisi bekleniyordu")
        }
        XCTAssertEqual(mostEfficient.displayName, "Eşarj • Maslak")
        XCTAssertNotNil(mostEfficient.averageTLPer100Km)
    }

    func testMakeReportSkipsPriceAndEfficiencySuggestionsWhenDataIsInsufficient() {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessions: [ChargingSession] = [
            makeSession(referenceDate: referenceDate, minutesAgo: 300, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 220, energy: 20, odometer: 1_000),
            makeSession(referenceDate: referenceDate, minutesAgo: 200, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 230, energy: 21, odometer: 1_080),
            makeSession(referenceDate: referenceDate, minutesAgo: 100, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 240, energy: 22, odometer: 1_170)
        ]

        let report = service.makeReport(sessions: sessions)

        XCTAssertEqual(report?.suggestions.count, 1)
        XCTAssertEqual(report?.suggestions.first?.category, .mostUsed)
        XCTAssertEqual(report?.suggestions.first?.displayName, "ZES • Kadikoy")
    }

    func testMakeReportReturnsNilWhenOnlyHomeSessionsExist() {
        let sessions: [ChargingSession] = [
            makeSession(minutesAgo: 60, method: .home, brand: "Ev Wallbox", location: "Garaj", price: 120, energy: 18, odometer: 5_000),
            makeSession(minutesAgo: 30, method: .home, brand: "Ev Wallbox", location: "Garaj", price: 118, energy: 17, odometer: 5_050)
        ]

        XCTAssertNil(service.makeReport(sessions: sessions))
    }

    private func makeSession(
        referenceDate: Date = .now,
        minutesAgo: Int,
        method: ChargeMethod,
        brand: String,
        location: String,
        price: Double,
        energy: Double,
        odometer: Double
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: vehicleID,
            sessionDate: referenceDate.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            chargeMethod: method,
            stationBrand: brand,
            locationName: location,
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            isFullCharge: false,
            durationMin: 45,
            odometerKM: odometer
        )
    }
}
#endif
