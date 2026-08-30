#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class InsightsViewModelTests: XCTestCase {
    func testLoadBuildsSingleActionableInsightAndPrefillsChargeScreen() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 30, method: .publicDC, price: 520, energy: 38, startSOC: 14, endSOC: 86),
            makeSession(vehicleID: vehicle.id, minutesAgo: 180, method: .publicDC, price: 470, energy: 34, startSOC: 16, endSOC: 88),
            makeSession(vehicleID: vehicle.id, minutesAgo: 360, method: .publicDC, price: 495, energy: 36, startSOC: 18, endSOC: 90),
            makeSession(vehicleID: vehicle.id, minutesAgo: 720, method: .publicAC, price: 250, energy: 31, startSOC: 24, endSOC: 78)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.actionableInsight?.recommendationType, .reduceDC)
        XCTAssertEqual(viewModel.actionableInsight?.suggestedAction.defaultChargeType, .ac)
        XCTAssertEqual(viewModel.chargeHabitSummary?.targetSummaryText, "DC %75, hedef %60")
        XCTAssertEqual(viewModel.chargeHabitSummary?.cta?.suggestedChargeType, .ac)
        XCTAssertFalse(viewModel.insightCards.contains { $0.detail.contains("Seanslarının") && $0.detail.contains("DC") })

        let suggestedChargeViewModel = try XCTUnwrap(viewModel.makeSuggestedChargeViewModel())
        XCTAssertEqual(suggestedChargeViewModel.chargeMethod, .publicAC)

        let firstInsight = viewModel.actionableInsight
        viewModel.load(referenceDate: .now)
        XCTAssertEqual(viewModel.actionableInsight, firstInsight)
    }

    func testLoadPrefersRealtimeSnapshotForVehicleEfficiencySummary() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)
        try env.vehicleMetricSnapshotRepository.replace(
            vehicleID: vehicle.id,
            snapshots: [
                VehicleMetricSnapshot(
                    vehicleID: vehicle.id,
                    period: .last365Days,
                    avgKWh100Km: 17.2,
                    avgTRY100Km: 142,
                    gasolineTRY100Km: 420,
                    savingTRY100Km: 278,
                    savingPercent: 66.2,
                    basisLabel: ConsumptionBlockConfidenceType.estimated.basisLabel
                )
            ]
        )

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.vehicleEfficiencySummary?.averageEnergyPer100Km.value ?? 0, 17.2, accuracy: 0.001)
        XCTAssertEqual(viewModel.vehicleEfficiencySummary?.averageEnergyPer100Km.isEstimated, true)
    }

    func testLoadBuildsTrendBreakInsightWhenThirtyDayComparisonBreaks() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23

        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-1 * 24 * 60 * 60)),
                chargeMethod: .publicDC,
                priceTotal: 560,
                currencyCode: "TRY",
                energyKWh: 35,
                energyIsEstimated: false,
                socStart: 15,
                socEnd: 84
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-3 * 24 * 60 * 60)),
                chargeMethod: .publicAC,
                priceTotal: 420,
                currencyCode: "TRY",
                energyKWh: 28,
                energyIsEstimated: false,
                socStart: 20,
                socEnd: 78
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-6 * 24 * 60 * 60)),
                chargeMethod: .home,
                priceTotal: 260,
                currencyCode: "TRY",
                energyKWh: 20,
                energyIsEstimated: false,
                socStart: 24,
                socEnd: 74
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-16 * 24 * 60 * 60)),
                chargeMethod: .publicAC,
                priceTotal: 250,
                currencyCode: "TRY",
                energyKWh: 30,
                energyIsEstimated: false,
                socStart: 22,
                socEnd: 80
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-20 * 24 * 60 * 60)),
                chargeMethod: .home,
                priceTotal: 180,
                currencyCode: "TRY",
                energyKWh: 22,
                energyIsEstimated: false,
                socStart: 28,
                socEnd: 76
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: referenceDate)

        XCTAssertNotNil(viewModel.trendBreakInsight)
    }

    func testLoadBuildsACHabitTargetWhenACRatioIsLow() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 30, method: .home, price: 170, energy: 18, startSOC: 24, endSOC: 61),
            makeSession(vehicleID: vehicle.id, minutesAgo: 180, method: .home, price: 160, energy: 17, startSOC: 20, endSOC: 56),
            makeSession(vehicleID: vehicle.id, minutesAgo: 360, method: .publicDC, price: 420, energy: 31, startSOC: 18, endSOC: 82)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.actionableInsight?.recommendationType, .increaseAC)
        XCTAssertEqual(viewModel.chargeHabitSummary?.targetSummaryText, "AC %0, hedef en az %25")
        XCTAssertTrue(viewModel.chargeHabitSummary?.recommendationText.contains("AC") == true)
    }

    func testLoadBuildsContextInsightsWhenTaggedHistoryIsSufficient() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 8_000, method: .publicAC, price: 180, energy: 16, startSOC: 20, endSOC: 50, odometer: 1_000, tags: [.cityDriving]),
            makeSession(vehicleID: vehicle.id, minutesAgo: 7_000, method: .publicAC, price: 240, energy: 16, startSOC: 24, endSOC: 62, odometer: 1_600, tags: [.cityDriving]),
            makeSession(vehicleID: vehicle.id, minutesAgo: 6_000, method: .publicDC, price: 260, energy: 18, startSOC: 18, endSOC: 58, odometer: 2_000, tags: [.longRoad]),
            makeSession(vehicleID: vehicle.id, minutesAgo: 5_000, method: .publicDC, price: 420, energy: 36, startSOC: 16, endSOC: 76, odometer: 2_600, tags: [.longRoad]),
            makeSession(vehicleID: vehicle.id, minutesAgo: 4_000, method: .publicDC, price: 430, energy: 42, startSOC: 18, endSOC: 78, odometer: 3_200, tags: [.longRoad])
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertFalse(viewModel.contextInsights.isEmpty)
        XCTAssertTrue(viewModel.contextInsights.contains { $0.id == "context.long_road_consumption" })
    }

    func testLoadBuildsPersonalRecordsWhenSessionDataIsAvailable() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 4_000, method: .publicAC, price: 220, energy: 40, startSOC: 20, endSOC: 82, odometer: 1_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 3_000, method: .publicDC, price: 520, energy: 29, startSOC: 18, endSOC: 80, odometer: 1_090),
            makeSession(vehicleID: vehicle.id, minutesAgo: 2_000, method: .publicAC, price: 260, energy: 50, startSOC: 24, endSOC: 84, odometer: 1_290)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertFalse(viewModel.personalRecords.isEmpty)
        XCTAssertTrue(viewModel.personalRecords.contains { $0.type == .cheapestCharge })
        XCTAssertTrue(viewModel.personalRecords.contains { $0.type == .mostEfficientCharge })
    }

    func testLoadBuildsSmartFavoriteStationReport() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 420, method: .publicAC, price: 210, energy: 30, startSOC: 20, endSOC: 80, odometer: 1_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 360, method: .publicAC, price: 220, energy: 31, startSOC: 22, endSOC: 82, odometer: 1_100),
            makeSession(vehicleID: vehicle.id, minutesAgo: 300, method: .publicAC, price: 205, energy: 29, startSOC: 24, endSOC: 78, odometer: 1_200),
            makeSession(vehicleID: vehicle.id, minutesAgo: 180, method: .publicDC, price: 390, energy: 24, startSOC: 18, endSOC: 76, odometer: 1_290),
            makeSession(vehicleID: vehicle.id, minutesAgo: 120, method: .publicDC, price: 400, energy: 25, startSOC: 16, endSOC: 75, odometer: 1_390)
        ]

        for (index, session) in sessions.enumerated() {
            var mutableSession = session
            if index < 3 {
                mutableSession.stationBrand = "ZES"
                mutableSession.locationName = "Kadikoy"
            } else {
                mutableSession.stationBrand = "Trugo"
                mutableSession.locationName = "Levent"
            }
            try env.logChargingSessionUseCase.execute(mutableSession)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        let report = try XCTUnwrap(viewModel.smartFavoriteStationReport)
        XCTAssertTrue(report.suggestions.contains { $0.category == .mostUsed })
        XCTAssertTrue(report.suggestions.contains { $0.category == .cheapest })
    }

    func testMakeSuggestedChargeViewModelPrefillsStationSuggestion() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 420, method: .publicAC, price: 210, energy: 30, startSOC: 20, endSOC: 80, odometer: 1_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 360, method: .publicAC, price: 220, energy: 31, startSOC: 22, endSOC: 82, odometer: 1_100),
            makeSession(vehicleID: vehicle.id, minutesAgo: 300, method: .publicAC, price: 205, energy: 29, startSOC: 24, endSOC: 78, odometer: 1_200)
        ]

        for session in sessions {
            var mutableSession = session
            mutableSession.stationBrand = "ZES"
            mutableSession.locationName = "Kadikoy"
            try env.logChargingSessionUseCase.execute(mutableSession)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        let suggestion = try XCTUnwrap(viewModel.smartFavoriteStationReport?.suggestions.first)
        let chargeViewModel = viewModel.makeSuggestedChargeViewModel(stationSuggestion: suggestion)

        XCTAssertEqual(chargeViewModel.chargeMethod, .publicAC)
        XCTAssertEqual(chargeViewModel.stationBrand, "ZES")
        XCTAssertEqual(chargeViewModel.locationName, "Kadikoy")
    }

    func testLoadBuildsUserChargingProfileWhenDataIsSufficient() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 720, method: .publicDC, price: 420, energy: 24, startSOC: 16, endSOC: 72, duration: 42),
            makeSession(vehicleID: vehicle.id, minutesAgo: 640, method: .publicDC, price: 460, energy: 26, startSOC: 14, endSOC: 78, duration: 44),
            makeSession(vehicleID: vehicle.id, minutesAgo: 560, method: .publicDC, price: 450, energy: 25, startSOC: 15, endSOC: 76, duration: 40),
            makeSession(vehicleID: vehicle.id, minutesAgo: 480, method: .publicDC, price: 470, energy: 27, startSOC: 18, endSOC: 80, duration: 46),
            makeSession(vehicleID: vehicle.id, minutesAgo: 400, method: .publicDC, price: 440, energy: 25, startSOC: 17, endSOC: 75, duration: 43),
            makeSession(vehicleID: vehicle.id, minutesAgo: 320, method: .publicAC, price: 260, energy: 30, startSOC: 22, endSOC: 81, duration: 50),
            makeSession(vehicleID: vehicle.id, minutesAgo: 240, method: .home, price: 130, energy: 16, startSOC: 30, endSOC: 58, duration: 45)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.userChargingProfile?.type, .speedFocused)
        XCTAssertTrue(viewModel.userChargingProfile?.description.contains("DC kullanımın yüksek") == true)
    }

    func testLoadBuildsExperimentSuggestionReportWhenDataAllows() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23
        let sessions: [ChargingSession] = [
            // Previous week
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-12 * 24 * 60 * 60)),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 90,
                currencyCode: "TRY",
                energyKWh: 15,
                energyIsEstimated: false,
                socStart: 24,
                socEnd: 78,
                isFullCharge: false,
                durationMin: 55
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-11 * 24 * 60 * 60)),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 420,
                currencyCode: "TRY",
                energyKWh: 25,
                energyIsEstimated: false,
                socStart: 18,
                socEnd: 84,
                isFullCharge: false,
                durationMin: 34
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-10 * 24 * 60 * 60)),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 90,
                currencyCode: "TRY",
                energyKWh: 15,
                energyIsEstimated: false,
                socStart: 24,
                socEnd: 78,
                isFullCharge: false,
                durationMin: 55
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-9 * 24 * 60 * 60)),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 420,
                currencyCode: "TRY",
                energyKWh: 25,
                energyIsEstimated: false,
                socStart: 18,
                socEnd: 84,
                isFullCharge: false,
                durationMin: 36
            ),
            // Recent week
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-5 * 24 * 60 * 60)),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 90,
                currencyCode: "TRY",
                energyKWh: 15,
                energyIsEstimated: false,
                socStart: 22,
                socEnd: 76,
                isFullCharge: false,
                durationMin: 53
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-4 * 24 * 60 * 60)),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 220,
                currencyCode: "TRY",
                energyKWh: 22,
                energyIsEstimated: false,
                socStart: 24,
                socEnd: 78,
                isFullCharge: false,
                durationMin: 52
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-2 * 24 * 60 * 60)),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 90,
                currencyCode: "TRY",
                energyKWh: 15,
                energyIsEstimated: false,
                socStart: 23,
                socEnd: 77,
                isFullCharge: false,
                durationMin: 54
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-1 * 24 * 60 * 60)),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 360,
                currencyCode: "TRY",
                energyKWh: 25,
                energyIsEstimated: false,
                socStart: 19,
                socEnd: 83,
                isFullCharge: false,
                durationMin: 35
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: referenceDate)

        XCTAssertEqual(viewModel.experimentSuggestionReport?.suggestion.type, .increaseAC)
        XCTAssertEqual(viewModel.experimentSuggestionReport?.resultInsight?.type, .increaseAC)
    }

    func testLoadBuildsRetentionPromptForGoalFollowUp() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)
        try env.goalRepository.saveGoals([
            UserGoal(type: .monthlyChargeEntries, targetValue: 10)
        ])

        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23
        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(TimeInterval(-4 * 24 * 60 * 60)),
                chargeMethod: .publicAC,
                priceTotal: 210,
                currencyCode: "TRY",
                energyKWh: 18,
                energyIsEstimated: false,
                socStart: 24,
                socEnd: 74
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: referenceDate)

        XCTAssertEqual(viewModel.retentionPrompt?.type, .goalFollowUpNeeded)
    }

    func testLoadBuildsAnalysisConfidenceForHabitAndEfficiencyCards() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 720, method: .publicAC, price: 180, energy: 18, startSOC: 22, endSOC: 76, odometer: 1_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 640, method: .publicAC, price: 190, energy: 19, startSOC: 20, endSOC: 74, odometer: 1_080),
            makeSession(vehicleID: vehicle.id, minutesAgo: 560, method: .publicDC, price: 350, energy: 24, startSOC: 16, endSOC: 81, odometer: 1_170),
            makeSession(vehicleID: vehicle.id, minutesAgo: 480, method: .home, price: 120, energy: 12, startSOC: 30, endSOC: 58, odometer: 1_220),
            makeSession(vehicleID: vehicle.id, minutesAgo: 400, method: .publicAC, price: 210, energy: 20, startSOC: 24, endSOC: 79, odometer: 1_305),
            makeSession(vehicleID: vehicle.id, minutesAgo: 320, method: .publicDC, price: 360, energy: 25, startSOC: 17, endSOC: 83, odometer: 1_390)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertNotNil(viewModel.chargeHabitAnalysisConfidence)
        XCTAssertNotNil(viewModel.vehicleEfficiencyAnalysisConfidence)
        XCTAssertTrue(
            viewModel.chargeHabitAnalysisConfidence?.primaryText.contains("gerçek veriye dayanıyor") == true
        )
    }

    func testLoadBuildsBestRangeInsightWhenReliableSessionPoolIsSufficient() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 900, method: .publicAC, price: 180, energy: 14, startSOC: 18, endSOC: 76, odometer: 1_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 720, method: .publicAC, price: 210, energy: 16, startSOC: 20, endSOC: 79, odometer: 1_090),
            makeSession(vehicleID: vehicle.id, minutesAgo: 540, method: .publicAC, price: 240, energy: 17, startSOC: 22, endSOC: 82, odometer: 1_190),
            makeSession(vehicleID: vehicle.id, minutesAgo: 360, method: .publicDC, price: 330, energy: 20, startSOC: 16, endSOC: 88, odometer: 1_300),
            makeSession(vehicleID: vehicle.id, minutesAgo: 180, method: .publicAC, price: 215, energy: 15, startSOC: 24, endSOC: 78, odometer: 1_395)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertNotNil(viewModel.chargeHabitMetricsSummary?.bestRangeInsight)
    }

    func testLoadSkipsBestRangeInsightWhenReliableDataIsInsufficient() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 240, method: .publicAC, price: 180, energy: 16, startSOC: 20, endSOC: 72),
            makeSession(vehicleID: vehicle.id, minutesAgo: 120, method: .publicDC, price: 320, energy: 25, startSOC: 18, endSOC: 84)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertNil(viewModel.chargeHabitMetricsSummary?.bestRangeInsight)
    }

    func testLoadFallsBackToFactoryConsumptionWhenEfficiencyChainLooksSuspicious() throws {
        let env = try AppEnvironment.live(inMemory: true)
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
            makeSession(vehicleID: vehicle.id, minutesAgo: 180, method: .publicAC, price: 150, energy: 8, startSOC: 28, endSOC: 44, odometer: 10_000),
            makeSession(vehicleID: vehicle.id, minutesAgo: 60, method: .publicAC, price: 260, energy: 21, startSOC: 16, endSOC: 62, odometer: 10_010)
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        let summary = try XCTUnwrap(viewModel.vehicleEfficiencySummary)
        XCTAssertTrue(summary.averageEnergyPer100Km.isEstimated)
        XCTAssertEqual(summary.averageEnergyPer100Km.value, 17.7, accuracy: 0.01)
        XCTAssertTrue(summary.supportingText.contains("tahmini"))
    }

    func testLoadUsesMeasuredEfficiencyWhenValidBlocksExistDespiteSomeInvalidTransitions() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let base = Date(timeIntervalSince1970: 1_775_193_600) // 2026-04-06
        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: base.addingTimeInterval(-3 * 24 * 60 * 60),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 120,
                currencyCode: "TRY",
                energyKWh: 10,
                energyIsEstimated: false,
                socStart: 20,
                socEnd: 32,
                isFullCharge: false,
                durationMin: 20,
                odometerKM: 10_000
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: base.addingTimeInterval(-2 * 24 * 60 * 60),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 840,
                currencyCode: "TRY",
                energyKWh: 80,
                energyIsEstimated: false,
                socStart: 25,
                socEnd: 70,
                isFullCharge: false,
                durationMin: 70
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: base.addingTimeInterval(-24 * 60 * 60),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 960,
                currencyCode: "TRY",
                energyKWh: 90,
                energyIsEstimated: false,
                socStart: 18,
                socEnd: 82,
                isFullCharge: false,
                durationMin: 80,
                odometerKM: 11_000
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: base,
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 180,
                currencyCode: "TRY",
                energyKWh: 15,
                energyIsEstimated: false,
                socStart: 30,
                socEnd: 54,
                isFullCharge: false,
                durationMin: 15,
                odometerKM: 10_900
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: base)

        let summary = try XCTUnwrap(viewModel.vehicleEfficiencySummary)
        XCTAssertTrue(summary.averageEnergyPer100Km.value > 17.7)
        XCTAssertNotEqual(summary.averageEnergyPer100Km.value, 17.7, accuracy: 0.001)
        XCTAssertFalse(summary.headline.contains("fabrika"))
    }

    private func makeSession(
        vehicleID: UUID,
        minutesAgo: Int,
        method: ChargeMethod,
        price: Double,
        energy: Double,
        startSOC: Double,
        endSOC: Double,
        duration: Int = 30,
        odometer: Double? = nil,
        tags: [ChargeContextTag] = []
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: vehicleID,
            sessionDate: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            chargeMethod: method,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: startSOC,
            socEnd: endSOC,
            isFullCharge: false,
            durationMin: duration,
            odometerKM: odometer,
            contextTags: tags
        )
    }
}
#endif
