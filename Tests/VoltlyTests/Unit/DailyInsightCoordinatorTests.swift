#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class DailyInsightCoordinatorTests: XCTestCase {
    func testConsumeDisplayableInsightKeepsSameInsightAvailableWithinSession() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let suiteName = "DailyInsightCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let sessions = [
            makeSession(vehicleID: vehicle.id, daysAgo: 0, tlPerKWh: 15),
            makeSession(vehicleID: vehicle.id, daysAgo: 1, tlPerKWh: 12),
            makeSession(vehicleID: vehicle.id, daysAgo: 2, tlPerKWh: 9)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let coordinator = DailyInsightCoordinator(
            vehicleRepository: env.vehicleRepository,
            chargingSessionRepository: env.chargingSessionRepository,
            settingsRepository: env.settingsRepository,
            userDefaults: defaults
        )

        let now = Date()
        coordinator.refreshCandidate(referenceDate: now)
        let first = coordinator.consumeDisplayableInsight(referenceDate: now)
        let second = coordinator.consumeDisplayableInsight(referenceDate: now.addingTimeInterval(60))

        XCTAssertEqual(first?.id, "rising-costs")
        XCTAssertEqual(second?.id, "rising-costs")
    }

    func testConsumeDisplayableInsightSuppressesSameInsightAcrossFreshCoordinatorWithin24Hours() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let suiteName = "DailyInsightCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let sessions = [
            makeSession(vehicleID: vehicle.id, daysAgo: 0, tlPerKWh: 15),
            makeSession(vehicleID: vehicle.id, daysAgo: 1, tlPerKWh: 12),
            makeSession(vehicleID: vehicle.id, daysAgo: 2, tlPerKWh: 9)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let now = Date()
        let firstCoordinator = DailyInsightCoordinator(
            vehicleRepository: env.vehicleRepository,
            chargingSessionRepository: env.chargingSessionRepository,
            settingsRepository: env.settingsRepository,
            userDefaults: defaults
        )
        firstCoordinator.refreshCandidate(referenceDate: now)
        XCTAssertEqual(
            firstCoordinator.consumeDisplayableInsight(referenceDate: now)?.id,
            "rising-costs"
        )

        let secondCoordinator = DailyInsightCoordinator(
            vehicleRepository: env.vehicleRepository,
            chargingSessionRepository: env.chargingSessionRepository,
            settingsRepository: env.settingsRepository,
            userDefaults: defaults
        )
        secondCoordinator.refreshCandidate(referenceDate: now.addingTimeInterval(60))
        XCTAssertNil(secondCoordinator.consumeDisplayableInsight(referenceDate: now.addingTimeInterval(60)))
    }

    private func makeSession(vehicleID: UUID, daysAgo: Int, tlPerKWh: Double) -> ChargingSession {
        let energy = 20.0
        let price = energy * tlPerKWh
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now

        return ChargingSession(
            vehicleID: vehicleID,
            sessionDate: date,
            chargeMethod: .publicDC,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 18,
            socEnd: 82,
            isFullCharge: false,
            durationMin: 30,
            odometerKM: 10_000
        )
    }
}
#endif
