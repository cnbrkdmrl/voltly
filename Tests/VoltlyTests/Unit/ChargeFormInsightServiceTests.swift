#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ChargeFormInsightServiceTests: XCTestCase {
    private let service = ChargeFormInsightService()

    func testMakeInsightComputesExactTLPer100KmWhenOdometerChainExists() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        let history = [
            makeSession(daysAgo: 10, method: .publicAC, price: 180, energy: 18, odometer: 9_000),
            makeSession(daysAgo: 4, method: .publicAC, price: 210, energy: 21, odometer: 9_500)
        ]
        let input = ChargeFormInsightInput(
            vehicle: vehicle,
            chargeMethod: .publicAC,
            priceTotal: 240,
            tariffPricePerKWh: nil,
            fallbackTariffPricePerKWh: nil,
            energyKWh: 24,
            energyIsEstimated: false,
            durationMinutes: 80,
            odometerKM: 10_050,
            currencyCode: "TRY"
        )

        let insight = service.makeInsight(input: input, history: history)

        XCTAssertEqual(insight.tlPerKWh.value ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(insight.tlPerKWh.confidence.source, .real)
        XCTAssertNotNil(insight.tlPer100Km.value)
        XCTAssertEqual(insight.tlPer100Km.confidence.source, .real)
    }

    func testMakeInsightSuggestsACWhenDCLooksMoreExpensive() {
        let vehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2026,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 16.5
        )
        let history = [
            makeSession(daysAgo: 8, method: .publicAC, price: 200, energy: 25, odometer: 8_000),
            makeSession(daysAgo: 5, method: .publicAC, price: 216, energy: 27, odometer: 8_240),
            makeSession(daysAgo: 2, method: .publicDC, price: 540, energy: 36, odometer: 8_480)
        ]
        let input = ChargeFormInsightInput(
            vehicle: vehicle,
            chargeMethod: .publicDC,
            priceTotal: 600,
            tariffPricePerKWh: nil,
            fallbackTariffPricePerKWh: nil,
            energyKWh: 40,
            energyIsEstimated: false,
            durationMinutes: 32,
            odometerKM: 8_760,
            currencyCode: "TRY"
        )

        let insight = service.makeInsight(input: input, history: history)

        XCTAssertEqual(insight.pricePosition.kind, .expensive)
        XCTAssertEqual(insight.alternativeSuggestion?.recommendedMethod, .publicAC)
        XCTAssertNotNil(insight.alternativeSuggestion?.estimatedSavings)
    }

    func testMakeInsightUsesHomeFallbackTariffWhenPriceMissing() {
        let vehicle = Vehicle(
            brand: "BYD",
            model: "Seal",
            year: 2025,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 16.0
        )
        let input = ChargeFormInsightInput(
            vehicle: vehicle,
            chargeMethod: .home,
            priceTotal: nil,
            tariffPricePerKWh: nil,
            fallbackTariffPricePerKWh: 3.2,
            energyKWh: 18,
            energyIsEstimated: true,
            durationMinutes: 180,
            odometerKM: nil,
            currencyCode: "TRY"
        )

        let insight = service.makeInsight(input: input, history: [])

        XCTAssertEqual(insight.tlPerKWh.value ?? 0, 3.2, accuracy: 0.001)
        XCTAssertEqual(insight.tlPerKWh.confidence.source, .estimated)
        XCTAssertNotNil(insight.tlPer100Km.value)
        XCTAssertEqual(insight.pricePosition.kind, .unavailable)
    }

    private func makeSession(
        daysAgo: Int,
        method: ChargeMethod,
        price: Double,
        energy: Double,
        odometer: Double
    ) -> ChargingSession {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate

        return ChargingSession(
            vehicleID: UUID(),
            sessionDate: sessionDate,
            chargeMethod: method,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            durationMin: 40,
            odometerKM: odometer
        )
    }
}
#endif
