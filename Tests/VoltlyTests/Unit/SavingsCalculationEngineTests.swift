#if canImport(XCTest)
import XCTest
@testable import Voltly

final class SavingsCalculationEngineTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_775_116_800) // 2026-03-28

    func testShortReliableDistanceUsesFactoryConsumptionBlock() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(
                vehicleID: vehicle.id,
                dayOffset: -20,
                energy: 20,
                price: 200,
                odometer: 10_000
            ),
            makeSession(
                vehicleID: vehicle.id,
                dayOffset: -10,
                energy: 32,
                price: 320,
                odometer: 10_200
            )
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .odometer)
        XCTAssertEqual(summary?.calculationMode.consumption, .factoryEstimated)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 18, accuracy: 0.01)
    }

    func testBlockDistanceUsesWeightedBlockAverageConsumption() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -18, energy: 20, price: 200, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -12, energy: 40, price: 400, odometer: 10_300),
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 44, price: 440, odometer: 10_600)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .odometer)
        XCTAssertEqual(summary?.calculationMode.consumption, .blockAverage)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 600, accuracy: 0.01)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 17.3333, accuracy: 0.01)
        XCTAssertEqual(summary?.evCostPer100Km ?? 0, 173.3333, accuracy: 0.01)
    }

    func testLargeReliableDistanceUsesRealWeightedConsumption() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -18, energy: 24, price: 240, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -12, energy: 60, price: 600, odometer: 10_500),
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 72, price: 720, odometer: 11_200)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .odometer)
        XCTAssertEqual(summary?.calculationMode.consumption, .realData)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 1_200, accuracy: 0.01)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 13, accuracy: 0.01)
        XCTAssertEqual(summary?.evCostPer100Km ?? 0, 130, accuracy: 0.01)
    }

    func testPrefersSmallestBlockAboveThousandKilometersFromLatestOdometer() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -24, energy: 30, price: 300, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -18, energy: 40, price: 400, odometer: 10_700),
            makeSession(vehicleID: vehicle.id, dayOffset: -10, energy: 50, price: 500, odometer: 11_100),
            makeSession(vehicleID: vehicle.id, dayOffset: -2, energy: 60, price: 600, odometer: 12_200)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .odometer)
        XCTAssertEqual(summary?.calculationMode.consumption, .realData)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 1_800, accuracy: 0.01)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 10, accuracy: 0.01)
        XCTAssertEqual(summary?.evCostPer100Km ?? 0, 100, accuracy: 0.01)
    }

    func testPrefersSmallestBlockAboveFiveHundredWhenNoRealBlockExists() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -18, energy: 20, price: 200, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -12, energy: 10, price: 100, odometer: 10_300),
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 24, price: 240, odometer: 10_650)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .odometer)
        XCTAssertEqual(summary?.calculationMode.consumption, .blockAverage)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 650, accuracy: 0.01)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 8.3076, accuracy: 0.01)
        XCTAssertEqual(summary?.evCostPer100Km ?? 0, 83.0769, accuracy: 0.01)
    }

    func testFallsBackToFactoryWhenClosestDeltaExceedsThreeThousandKilometers() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -10, energy: 40, price: 400, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 45, price: 450, odometer: 13_200)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.consumption, .factoryEstimated)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 18, accuracy: 0.01)
    }

    func testNoOdometerFallsBackToFactoryConsumption() {
        let vehicle = makeVehicle(factoryConsumption: 19)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -8, energy: 30, price: 300, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -2, energy: 20, price: 200, odometer: nil)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .energyEstimated)
        XCTAssertEqual(summary?.calculationMode.consumption, .factoryEstimated)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 19, accuracy: 0.01)
    }

    func testPartialOdometerUsesHybridDistance() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -9, energy: 20, price: 200, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 20, price: 200, odometer: 10_100),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 20, price: 200, odometer: nil)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.distance, .hybrid)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 333.33, accuracy: 0.01)
    }

    func testInvalidRealConsumptionFallsBackAndWarns() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 30, price: 300, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 10, price: 100, odometer: 11_000)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.calculationMode.consumption, .factoryEstimated)
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 18, accuracy: 0.01)
        XCTAssertTrue(summary?.warnings.contains(where: { $0.id == "consumption.invalid" }) == true)
    }

    func testPotentialUnitInversionProducesWarning() {
        let vehicle = makeVehicle(factoryConsumption: nil)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 20, price: 200, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 22, price: 220, odometer: 10_900)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertTrue(summary?.warnings.contains(where: { $0.id == "consumption.unit_inversion" || $0.id == "consumption.invalid" }) == true)
        XCTAssertGreaterThanOrEqual(summary?.avgConsumptionKWh100km ?? 0, 5)
    }

    func testNegativeSavingsArePreserved() {
        let vehicle = makeVehicle(factoryConsumption: 20)
        let preferences = FuelBaselineSettings(
            fuelPricePerLiter: 10,
            iceConsumptionLPer100Km: 5,
            currencyCode: "TRY",
            electricityPricePerKWh: 8
        )
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 20, price: 400, odometer: nil)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions, preferences: preferences).allTime
        XCTAssertLessThan(summary?.savingsAmount ?? 0, 0)
        XCTAssertLessThan(summary?.savingsPercent ?? 0, 0)
    }

    func testMissingPriceUsesElectricityPriceFallback() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let preferences = FuelBaselineSettings(
            fuelPricePerLiter: 60,
            iceConsumptionLPer100Km: 7,
            currencyCode: "TRY",
            electricityPricePerKWh: 8
        )
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 10, price: 0, odometer: nil)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions, preferences: preferences).allTime
        XCTAssertEqual(summary?.totalEvCost ?? 0, 80, accuracy: 0.01)
        XCTAssertTrue(summary?.warnings.contains(where: { $0.id == "price.fallback" }) == true)
    }

    func testManySuspiciousSessionsLowerConfidence() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -4, energy: 12, price: 120, odometer: nil, startSOC: 0, endSOC: 0),
            makeSession(vehicleID: vehicle.id, dayOffset: -3, energy: 13, price: 130, odometer: nil, startSOC: 0, endSOC: 0),
            makeSession(vehicleID: vehicle.id, dayOffset: -2, energy: 14, price: 140, odometer: nil, startSOC: 0, endSOC: 0),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 15, price: 150, odometer: nil, startSOC: 0, endSOC: 0)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.confidenceLevel, .low)
    }

    func testThisMonthAndAllTimeStayIndependent() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let currentMonthSession = makeSession(
            vehicleID: vehicle.id,
            dayOffset: 0,
            energy: 10,
            price: 100,
            odometer: 10_000
        )
        let oldSessionDate = Calendar.current.date(byAdding: .month, value: -2, to: referenceDate) ?? referenceDate
        let oldSession = ChargingSession(
            vehicleID: vehicle.id,
            sessionDate: oldSessionDate,
            chargeMethod: .publicAC,
            priceTotal: 200,
            energyKWh: 20,
            socStart: 20,
            socEnd: 80,
            odometerKM: 10_200
        )

        let report = makeReport(vehicle: vehicle, sessions: [currentMonthSession, oldSession])
        XCTAssertEqual(report.thisMonth?.sessionCount, 1)
        XCTAssertEqual(report.allTime?.sessionCount, 2)
    }

    func testFuelPriceChangeRecomputesGasolineEquivalent() {
        let vehicle = makeVehicle(factoryConsumption: 18)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 20, price: 180, odometer: nil)
        ]
        let lowFuel = FuelBaselineSettings(
            fuelPricePerLiter: 40,
            iceConsumptionLPer100Km: 7,
            currencyCode: "TRY",
            electricityPricePerKWh: 8
        )
        let highFuel = FuelBaselineSettings(
            fuelPricePerLiter: 70,
            iceConsumptionLPer100Km: 7,
            currencyCode: "TRY",
            electricityPricePerKWh: 8
        )

        let lowSummary = makeReport(vehicle: vehicle, sessions: sessions, preferences: lowFuel).allTime
        let highSummary = makeReport(vehicle: vehicle, sessions: sessions, preferences: highFuel).allTime
        XCTAssertNotEqual(lowSummary?.gasolineEquivalentCost, highSummary?.gasolineEquivalentCost)
    }

    func testAbsurdLowConsumptionNeverLeaksToUI() {
        let vehicle = makeVehicle(factoryConsumption: 19)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -6, energy: 30, price: 300, odometer: 20_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 24, price: 240, odometer: 21_000)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        let value = summary?.avgConsumptionKWh100km ?? 0
        XCTAssertFalse(abs(value - 2.4) < 0.01)
        XCTAssertGreaterThanOrEqual(value, 5)
    }

    func testMonthlySavingsUsesPeriodTotalsWithWeightedBlockConsumption() {
        let vehicle = makeVehicle(factoryConsumption: 17.7)
        let sessions = [
            makeSession(vehicleID: vehicle.id, dayOffset: -24, energy: 120, price: 1_380, odometer: 17_000),
            makeSession(vehicleID: vehicle.id, dayOffset: -20, energy: 160, price: 1_920, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -18, energy: 181.414, price: 2_011.64, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -10, energy: 28.64, price: 472.34, odometer: 18_399),
            makeSession(vehicleID: vehicle.id, dayOffset: -9, energy: 100, price: 1_000, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -8, energy: 100, price: 1_000, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -7, energy: 32.881, price: 486.06, odometer: nil),
            makeSession(vehicleID: vehicle.id, dayOffset: -1, energy: 47.49, price: 450.68, odometer: 19_399)
        ]

        let summary = makeReport(vehicle: vehicle, sessions: sessions).allTime
        XCTAssertEqual(summary?.avgConsumptionKWh100km ?? 0, 30.9011, accuracy: 0.01)
        XCTAssertEqual(summary?.estimatedDistanceKm ?? 0, 2_493.20, accuracy: 0.05)
        XCTAssertEqual(summary?.evCostPer100Km ?? 0, 349.78, accuracy: 0.05)
        XCTAssertEqual(summary?.gasolineEquivalentCost ?? 0, 10_533.75, accuracy: 0.1)
        XCTAssertEqual(summary?.savingsAmount ?? 0, 1_813.03, accuracy: 0.1)
        XCTAssertEqual(summary?.savingsPercent ?? 0, 17.21, accuracy: 0.1)
    }

    private func makeReport(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        preferences: FuelBaselineSettings = FuelBaselineSettings(
            fuelPricePerLiter: 65,
            iceConsumptionLPer100Km: 6.5,
            currencyCode: "TRY",
            electricityPricePerKWh: 8.5
        )
    ) -> SavingsCalculationReport {
        SavingsCalculationEngine().calculate(
            vehicle: vehicle,
            sessions: sessions,
            preferences: preferences,
            referenceDate: referenceDate
        )
    }

    private func makeVehicle(factoryConsumption: Double?) -> Vehicle {
        Vehicle(
            id: UUID(),
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: factoryConsumption
        )
    }

    private func makeSession(
        vehicleID: UUID,
        dayOffset: Int,
        energy: Double?,
        price: Double,
        odometer: Double?,
        startSOC: Double = 20,
        endSOC: Double = 80
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: vehicleID,
            sessionDate: Calendar.current.date(byAdding: .day, value: dayOffset, to: referenceDate) ?? referenceDate,
            chargeMethod: .publicAC,
            priceTotal: price,
            energyKWh: energy,
            socStart: startSOC,
            socEnd: endSOC,
            durationMin: 60,
            odometerKM: odometer
        )
    }
}
#endif
