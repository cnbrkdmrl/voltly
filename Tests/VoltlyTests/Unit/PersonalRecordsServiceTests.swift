#if canImport(XCTest)
import XCTest
@testable import Voltly

final class PersonalRecordsServiceTests: XCTestCase {
    private let service = PersonalRecordsService()

    func testGenerateRecordsBuildsExpectedRecordSetAndIgnoresSuspiciousData() {
        let vehicle = makeVehicle()
        let session1 = makeSession(
            dayOffset: -6,
            price: 200,
            energy: 40,
            duration: 120,
            odometer: 1_000
        )
        let session2 = makeSession(
            dayOffset: -5,
            price: 600,
            energy: 30,
            duration: 35,
            odometer: 1_100
        )
        let session3 = makeSession(
            dayOffset: -4,
            price: 300,
            energy: 50,
            duration: 200,
            odometer: 1_300
        )
        let session4 = makeSession(
            dayOffset: -3,
            price: 260,
            energy: 28,
            duration: 25,
            odometer: 1_500
        )
        let session5 = makeSession(
            dayOffset: -2,
            price: 400,
            energy: 32,
            duration: 300,
            odometer: 1_700
        )
        let suspicious = makeSession(
            dayOffset: -1,
            price: 900,
            energy: 0.1,
            duration: 1,
            odometer: 1_710
        )

        let records = service.generateRecords(
            vehicle: vehicle,
            sessions: [session1, session2, session3, session4, session5, suspicious]
        )

        XCTAssertEqual(records.count, 6)
        XCTAssertEqual(record(for: .cheapestCharge, in: records)?.session.id, session1.id)
        XCTAssertEqual(record(for: .mostExpensiveCharge, in: records)?.session.id, session2.id)
        XCTAssertEqual(record(for: .highestEnergySession, in: records)?.session.id, session3.id)
        XCTAssertEqual(record(for: .shortestSession, in: records)?.session.id, session4.id)
        XCTAssertEqual(record(for: .longestSession, in: records)?.session.id, session5.id)
        XCTAssertEqual(record(for: .mostEfficientCharge, in: records)?.session.id, session4.id)
    }

    func testGenerateRecordsFallsBackToEstimatedEfficiencyWhenOdometerMissing() {
        let vehicle = makeVehicle()
        let sessions = [
            makeSession(dayOffset: -4, price: 230, energy: 30, duration: 80, odometer: nil),
            makeSession(dayOffset: -3, price: 210, energy: 31, duration: 82, odometer: nil),
            makeSession(dayOffset: -2, price: 320, energy: 30, duration: 36, odometer: nil)
        ]

        let records = service.generateRecords(vehicle: vehicle, sessions: sessions)
        let efficientRecord = record(for: .mostEfficientCharge, in: records)

        XCTAssertNotNil(efficientRecord)
        XCTAssertEqual(efficientRecord?.confidence.source, .estimated)
    }

    private func record(
        for type: PersonalRecordType,
        in records: [PersonalRecordItem]
    ) -> PersonalRecordItem? {
        records.first { $0.type == type }
    }

    private func makeVehicle() -> Vehicle {
        Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )
    }

    private func makeSession(
        dayOffset: Int,
        price: Double,
        energy: Double,
        duration: Int?,
        odometer: Double?
    ) -> ChargingSession {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: referenceDate) ?? referenceDate

        return ChargingSession(
            id: UUID(),
            vehicleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            sessionDate: sessionDate,
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
            durationMin: duration,
            odometerKM: odometer
        )
    }
}
#endif

