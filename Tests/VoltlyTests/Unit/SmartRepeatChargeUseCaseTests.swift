#if canImport(XCTest)
import XCTest
@testable import Voltly

final class SmartRepeatChargeUseCaseTests: XCTestCase {
    private let useCase = SmartRepeatChargeUseCase()

    func testExecuteReturnsPrefillAndRecommendationForCheaperAlternative() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )
        let sessions = [
            makeSession(daysAgo: 0, method: .publicDC, station: "Trugo", location: "Kentpark", price: 620, energy: 40),
            makeSession(daysAgo: 2, method: .publicAC, station: "ZES", location: "Kentpark", price: 250, energy: 32),
            makeSession(daysAgo: 4, method: .publicAC, station: "ZES", location: "Kentpark", price: 260, energy: 33),
            makeSession(daysAgo: 7, method: .publicDC, station: "Trugo", location: "Kentpark", price: 590, energy: 39)
        ]

        let plan = useCase.execute(
            vehicle: vehicle,
            sessions: sessions,
            electricityPricePerKWh: 8.5
        )

        XCTAssertNotNil(plan)
        XCTAssertEqual(plan?.prefill.chargeMethod, .publicDC)
        XCTAssertEqual(plan?.prefill.stationBrand, "Trugo")
        XCTAssertEqual(plan?.recommendation?.recommendedMethod, .publicAC)
        XCTAssertTrue(plan?.recommendation?.reason.contains("AC") == true)
    }

    func testExecuteReturnsNilWhenNoSessionsExist() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        let plan = useCase.execute(
            vehicle: vehicle,
            sessions: [],
            electricityPricePerKWh: 8.5
        )

        XCTAssertNil(plan)
    }

    private func makeSession(
        daysAgo: Int,
        method: ChargeMethod,
        station: String,
        location: String,
        price: Double,
        energy: Double
    ) -> ChargingSession {
        let baseDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: baseDate) ?? baseDate
        return ChargingSession(
            vehicleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            sessionDate: sessionDate,
            chargeMethod: method,
            stationBrand: station,
            locationName: location,
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            durationMin: method == .publicDC ? 35 : 80
        )
    }
}
#endif
