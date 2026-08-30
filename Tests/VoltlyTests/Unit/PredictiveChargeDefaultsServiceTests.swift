#if canImport(XCTest)
import XCTest
@testable import Voltly

final class PredictiveChargeDefaultsServiceTests: XCTestCase {
    private let service = PredictiveChargeDefaultsService()

    func testMakeReportBuildsExpectedQuickPresets() {
        let sessions = [
            makeSession(daysAgo: 9, method: .home, brand: "Ev", location: "Bursa", price: 140, energy: 28, startSOC: 25, endSOC: 80, duration: 240),
            makeSession(daysAgo: 6, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 210, energy: 30, startSOC: 22, endSOC: 82, duration: 95),
            makeSession(daysAgo: 4, method: .publicAC, brand: "ZES", location: "Kadikoy", price: 224, energy: 32, startSOC: 24, endSOC: 84, duration: 100),
            makeSession(daysAgo: 2, method: .publicDC, brand: "Trugo", location: "Anadolu Otoyol", price: 510, energy: 34, startSOC: 16, endSOC: 74, duration: 28),
            makeSession(daysAgo: 1, method: .publicDC, brand: "Trugo", location: "Anadolu Otoyol", price: 540, energy: 36, startSOC: 14, endSOC: 78, duration: 30)
        ]

        let report = service.makeReport(
            sessions: sessions,
            availableHomeProfiles: [
                HomeChargingProfile(id: 1, isEnabled: true, name: "Ev Wallbox", location: "Bursa", tariffPricePerKWh: 3.4)
            ],
            selectedHomeProfileID: 1,
            defaultElectricityTariffPerKWh: 3.4,
            referenceDate: Date(timeIntervalSince1970: 1_763_328_000)
        )

        XCTAssertNil(report?.dominantMethod)
        XCTAssertEqual(report?.quickPresets.count, 3)
        XCTAssertEqual(report?.quickPresets.map(\.kind), [.homeRoutine, .publicACFavorite, .roadTripDC])
        XCTAssertEqual(report?.quickPresets.first?.prefill.selectedHomeProfileID, 1)
        XCTAssertEqual(report?.quickPresets[0].title, "Ev")
        XCTAssertEqual(report?.quickPresets[1].title, "AC")
        XCTAssertEqual(report?.quickPresets[2].title, "DC")
    }

    func testMakeReportReturnsNilWhenThereIsNoHistory() {
        let report = service.makeReport(
            sessions: [],
            availableHomeProfiles: [],
            selectedHomeProfileID: 1,
            defaultElectricityTariffPerKWh: nil
        )

        XCTAssertNil(report)
    }

    private func makeSession(
        daysAgo: Int,
        method: ChargeMethod,
        brand: String,
        location: String,
        price: Double,
        energy: Double,
        startSOC: Double,
        endSOC: Double,
        duration: Int
    ) -> ChargingSession {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate

        return ChargingSession(
            vehicleID: UUID(),
            sessionDate: sessionDate,
            chargeMethod: method,
            stationBrand: brand,
            locationName: location,
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: startSOC,
            socEnd: endSOC,
            durationMin: duration
        )
    }
}
#endif
