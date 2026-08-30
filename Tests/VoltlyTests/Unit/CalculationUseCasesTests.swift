#if canImport(XCTest)
import XCTest
@testable import Voltly

final class CalculationUseCasesTests: XCTestCase {
    func testEstimatedEnergyCalculation() {
        let sut = CalculateEstimatedEnergyUseCase()
        let result = sut.execute(batteryCapacityKWh: 73, socStart: 20, socEnd: 80)
        XCTAssertEqual(result, 43.8, accuracy: 0.001)
    }

    func testTLPerKWhCalculation() {
        let sut = CalculateTLPerKWhUseCase()
        let result = sut.execute(priceTotal: 438, energyKWh: 43.8)
        XCTAssertEqual(try XCTUnwrap(result), 10, accuracy: 0.001)
    }

    func testTLPerKWhReturnsNilForZeroEnergy() {
        let sut = CalculateTLPerKWhUseCase()
        XCTAssertNil(sut.execute(priceTotal: 438, energyKWh: 0))
    }

    func testTLPer100KmFallsBackToFactoryBelowFiveHundredKilometers() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 1),
                chargeMethod: .home,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 20,
                socEnd: 70,
                odometerKM: 10_000
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 2),
                chargeMethod: .publicAC,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 30,
                socEnd: 80,
                odometerKM: 10_200
            )
        ]

        let result = CalculateTLPer100KmUseCase().execute(vehicle: vehicle, sessions: sessions)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEstimated ?? false)
        XCTAssertEqual(result?.value ?? 0, 180, accuracy: 0.1)
    }

    func testEnergyPer100KmReturnsNilBelowFiveHundredKilometers() {
        let vehicleID = UUID()
        let sessions = [
            ChargingSession(
                vehicleID: vehicleID,
                sessionDate: Date(timeIntervalSince1970: 1),
                chargeMethod: .home,
                priceTotal: 200,
                energyKWh: 20,
                socStart: 20,
                socEnd: 60,
                odometerKM: 10_000
            ),
            ChargingSession(
                vehicleID: vehicleID,
                sessionDate: Date(timeIntervalSince1970: 2),
                chargeMethod: .publicAC,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 40,
                socEnd: 80,
                odometerKM: 10_200
            )
        ]

        let result = CalculateEnergyPer100KmUseCase().execute(sessions: sessions)
        XCTAssertNil(result)
    }

    func testEnergyPer100KmUsesNearestEstimatedBlockAboveFiveHundredKilometers() {
        let vehicleID = UUID()
        let sessions = [
            ChargingSession(
                vehicleID: vehicleID,
                sessionDate: Date(timeIntervalSince1970: 1),
                chargeMethod: .home,
                priceTotal: 200,
                energyKWh: 20,
                socStart: 20,
                socEnd: 60,
                odometerKM: 10_000
            ),
            ChargingSession(
                vehicleID: vehicleID,
                sessionDate: Date(timeIntervalSince1970: 2),
                chargeMethod: .publicAC,
                priceTotal: 100,
                energyKWh: 10,
                socStart: 30,
                socEnd: 50,
                odometerKM: 10_300
            ),
            ChargingSession(
                vehicleID: vehicleID,
                sessionDate: Date(timeIntervalSince1970: 3),
                chargeMethod: .publicAC,
                priceTotal: 240,
                energyKWh: 24,
                socStart: 40,
                socEnd: 75,
                odometerKM: 10_650
            )
        ]

        let result = CalculateEnergyPer100KmUseCase().execute(sessions: sessions)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEstimated ?? false)
        XCTAssertEqual(result?.value ?? 0, 8.3076, accuracy: 0.01)
    }

    func testTLPer100KmUsesNearestRealBlockAboveOneThousandKilometers() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 1),
                chargeMethod: .home,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 20,
                socEnd: 60,
                odometerKM: 10_000
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 2),
                chargeMethod: .publicAC,
                priceTotal: 400,
                energyKWh: 40,
                socStart: 30,
                socEnd: 70,
                odometerKM: 10_700
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 3),
                chargeMethod: .publicDC,
                priceTotal: 500,
                energyKWh: 50,
                socStart: 15,
                socEnd: 80,
                odometerKM: 11_100
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date(timeIntervalSince1970: 4),
                chargeMethod: .publicDC,
                priceTotal: 600,
                energyKWh: 60,
                socStart: 20,
                socEnd: 90,
                odometerKM: 12_200
            )
        ]

        let result = CalculateTLPer100KmUseCase().execute(vehicle: vehicle, sessions: sessions)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isEstimated ?? true)
        XCTAssertEqual(result?.value ?? 0, 100, accuracy: 0.1)
    }

    func testGasolineComparisonCalculation() {
        let baseline = FuelBaselineSettings(fuelPricePerLiter: 45, iceConsumptionLPer100Km: 8)
        let result = CalculateGasolineComparisonUseCase().execute(tlPer100km: 180, baseline: baseline)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.savingsAmount ?? 0, 180, accuracy: 0.01)
        XCTAssertEqual(result?.percentCheaper ?? 0, 50, accuracy: 0.01)
    }
}
#endif
