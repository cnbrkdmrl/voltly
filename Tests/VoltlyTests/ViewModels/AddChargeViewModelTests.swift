#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class AddChargeViewModelTests: XCTestCase {
    func testUsesEstimatedEnergyWhenInputMissing() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.socStart = 20
        vm.socEnd = 80
        vm.totalPrice = "438"

        XCTAssertTrue(vm.energyIsEstimated)
        XCTAssertEqual(vm.selectedEnergyKWh ?? 0, 43.8, accuracy: 0.01)
    }

    func testSaveMarksFullChargeWhenSocEndsAt100() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.totalPrice = "500"
        vm.socStart = 40
        vm.socEnd = 100

        assertSaveSucceeded(vm.save())

        let sessions = try env.listChargingSessionsUseCase.execute(vehicleID: vehicle.id)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.isFullCharge, true)
    }

    func testSaveReturnsRealtimeMetricsUpdatePayload() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-3_600),
                chargeMethod: .publicAC,
                priceTotal: 240,
                energyKWh: 24,
                socStart: 20,
                socEnd: 60,
                odometerKM: 10_000
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.totalPrice = "360"
        vm.energyInput = "36"
        vm.odometerKM = "11100"

        switch vm.save() {
        case .success(let payload):
            XCTAssertNotNil(payload.realtimeMetricsUpdate)
            XCTAssertEqual(payload.realtimeMetricsUpdate?.latestBlock?.confidenceType, .real)
            XCTAssertEqual(vm.latestRealtimeMetricsUpdate?.latestBlock?.confidenceType, .real)
        case .failure:
            XCTFail("save should succeed")
        }
    }

    func testCalculatesChargeSpeedFromEnergyAndDuration() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.energyInput = "30"
        vm.durationMin = "45"

        XCTAssertEqual(vm.estimatedChargeSpeedKW ?? 0, 40, accuracy: 0.01)
    }

    func testPastDatedHomeSessionMakesSOCOptional() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.home)
        vm.setSessionDate(Date().addingTimeInterval(-86_400))
        vm.totalPrice = "500"

        XCTAssertFalse(vm.shouldShowSOCSelection)
        assertSaveSucceeded(vm.save())

        let sessions = try env.listChargingSessionsUseCase.execute(vehicleID: vehicle.id)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.socStart, 0)
        XCTAssertEqual(sessions.first?.socEnd, 0)
    }

    func testPastDatedDCSessionMakesSOCOptional() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicDC)
        vm.setSessionDate(Date().addingTimeInterval(-86_400))
        vm.totalPrice = "420"

        XCTAssertFalse(vm.shouldShowSOCSelection)
        assertSaveSucceeded(vm.save())

        let sessions = try env.listChargingSessionsUseCase.execute(vehicleID: vehicle.id)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.socStart, 0)
        XCTAssertEqual(sessions.first?.socEnd, 0)
    }

    func testPastDatedSessionCanSaveWithSOCWhenUserProvidesValues() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.home)
        vm.setSessionDate(Date().addingTimeInterval(-86_400))
        vm.setIncludeSOCForPastDate(true)
        vm.socStart = 18
        vm.socEnd = 76
        vm.totalPrice = "390"

        XCTAssertTrue(vm.shouldShowSOCSelection)
        assertSaveSucceeded(vm.save())

        let sessions = try env.listChargingSessionsUseCase.execute(vehicleID: vehicle.id)
        XCTAssertEqual(sessions.count, 1)
        let first = try XCTUnwrap(sessions.first)
        XCTAssertEqual(first.socStart, 18, accuracy: 0.001)
        XCTAssertEqual(first.socEnd, 76, accuracy: 0.001)
    }

    func testAutoFillsLatestLocationForSameStationBrand() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-3600),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 300,
                energyKWh: 30,
                socStart: 20,
                socEnd: 70
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-600),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Besiktas",
                priceTotal: 320,
                energyKWh: 32,
                socStart: 25,
                socEnd: 75
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.stationBrand = "zes"
        vm.onStationBrandChanged()

        XCTAssertEqual(vm.locationName, "Besiktas")
    }

    func testAutoSelectsMethodForSameStationBrandAndLocation() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-600),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Levent",
                priceTotal: 350,
                energyKWh: 20,
                socStart: 35,
                socEnd: 80
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.home)
        vm.stationBrand = "zes"
        vm.onStationBrandChanged()
        vm.locationName = "levent"
        vm.onLocationNameChanged()

        XCTAssertEqual(vm.chargeMethod, .publicDC)
    }

    func testDefaultTariffAutofillsOnlyForHomeMethod() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.tariff.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let vm = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertEqual(vm.chargeMethod, .home)
        XCTAssertEqual(vm.tariffPricePerKWh, "11")

        vm.setChargeMethod(.publicAC)
        XCTAssertEqual(vm.tariffPricePerKWh, "")

        vm.setChargeMethod(.home)
        XCTAssertEqual(vm.tariffPricePerKWh, "11")
    }

    func testHomeMethodUsesChargingDefaultsProfileInsteadOfLastSavedHomeValues() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.homeDefaults.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("Eski Ev", forKey: "add_charge.last.home.station")
        defaults.set("Eski Konum", forKey: "add_charge.last.home.location")

        HomeChargingPreferencesStore.save(
            HomeChargingPreferences(
                profiles: [
                    HomeChargingProfile(id: 1, isEnabled: true, name: "Yeni Ev", location: "Bursa Geçit", tariffPricePerKWh: 3.2),
                    HomeChargingProfile(id: 2, isEnabled: false, name: "", location: "", tariffPricePerKWh: nil),
                    HomeChargingProfile(id: 3, isEnabled: false, name: "", location: "", tariffPricePerKWh: nil)
                ],
                defaultProfileID: 1
            ),
            defaults: defaults
        )

        let vm = AddChargeViewModel(environment: env, userDefaults: defaults)
        vm.setChargeMethod(.publicAC)
        vm.setChargeMethod(.home)

        XCTAssertEqual(vm.stationBrand, "Yeni Ev")
        XCTAssertEqual(vm.locationName, "Bursa Geçit")
    }

    func testHomeProfileOverridesDraftLocationWhenMethodIsHome() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.homeDraft.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        HomeChargingPreferencesStore.save(
            HomeChargingPreferences(
                profiles: [
                    HomeChargingProfile(id: 1, isEnabled: true, name: "Ev Wallbox", location: "Mudanya", tariffPricePerKWh: 3.1),
                    HomeChargingProfile(id: 2, isEnabled: false, name: "", location: "", tariffPricePerKWh: nil),
                    HomeChargingProfile(id: 3, isEnabled: false, name: "", location: "", tariffPricePerKWh: nil)
                ],
                defaultProfileID: 1
            ),
            defaults: defaults
        )

        let draftWriter = AddChargeViewModel(environment: env, userDefaults: defaults)
        draftWriter.setChargeMethod(.home)
        draftWriter.stationBrand = "Eski Draft Ev"
        draftWriter.locationName = "Eski Draft Konum"
        draftWriter.totalPrice = "150"
        draftWriter.persistDraft()

        let vm = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertEqual(vm.chargeMethod, .home)
        XCTAssertEqual(vm.stationBrand, "Ev Wallbox")
        XCTAssertEqual(vm.locationName, "Mudanya")
    }

    func testSOCValidationRequiresEndGreaterThanStart() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.socStart = 60
        vm.socEnd = 60
        vm.totalPrice = "200"

        XCTAssertEqual(vm.socValidationMessage, "Şarj yüzdesi başlangıçtan büyük olmalı.")
        XCTAssertFalse(vm.canSave)
    }

    func testFriendlyValidationMessagesForEnergyAndPrice() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.totalPrice = "0"
        vm.energyInput = "0"

        XCTAssertEqual(vm.totalPriceValidationMessage, "Toplam ücret 0'dan büyük olmalı.")
        XCTAssertEqual(vm.energyValidationMessage, "Enerji değeri 0'dan büyük olmalı.")
    }

    func testWarnsWhenEnergyEnteredWithoutPrice() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.energyInput = "12.4"
        vm.totalPrice = ""
        vm.tariffPricePerKWh = ""

        XCTAssertEqual(
            vm.energyPriceConsistencyWarningMessage,
            "Enerji girdin, toplam ücret veya tarife bilgisi de eklemelisin."
        )
        XCTAssertFalse(vm.canSave)

        let result = vm.save()
        guard case .failure = result else {
            return XCTFail("Kayit bu durumda basarisiz olmaliydi")
        }
        XCTAssertEqual(vm.message, "Enerji girdin, toplam ücret veya tarife bilgisi de eklemelisin.")
    }

    func testChargeSpeedValidationWarnsForACOutOfRange() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicAC)
        vm.totalPrice = "320"
        vm.energyInput = "30"
        vm.durationMin = "15"

        XCTAssertNotNil(vm.chargeSpeedValidationMessage)
        XCTAssertTrue(vm.shouldIgnoreChargeSpeedInAnalysis)
        XCTAssertNil(vm.effectiveChargeSpeedKWForAnalysis)
    }

    func testOutOfRangeChargeSpeedWarningDoesNotBlockSave() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicDC)
        vm.totalPrice = "410"
        vm.energyInput = "12"
        vm.durationMin = "120"

        XCTAssertNotNil(vm.chargeSpeedValidationMessage)
        XCTAssertTrue(vm.canSave)
        assertSaveSucceeded(vm.save())
    }

    func testRepeatLastChargeAutofillsRequestedFields() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-300),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Forum Ankara",
                priceTotal: 620,
                energyKWh: 40,
                socStart: 20,
                socEnd: 80
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.socStart = 15
        vm.socEnd = 75
        vm.totalPrice = "540"
        vm.energyInput = "30"

        XCTAssertTrue(vm.canRepeatLastCharge)
        vm.repeatLastCharge()

        XCTAssertEqual(vm.chargeMethod, .publicDC)
        XCTAssertEqual(vm.stationBrand, "Trugo")
        XCTAssertEqual(vm.locationName, "Forum Ankara")
        XCTAssertEqual(vm.tariffPricePerKWh, "15.5")
        XCTAssertEqual(vm.socStart, 15, accuracy: 0.001)
        XCTAssertEqual(vm.socEnd, 75, accuracy: 0.001)
        XCTAssertEqual(vm.totalPrice, "540")
        XCTAssertEqual(vm.energyInput, "30")
        XCTAssertNotNil(vm.smartRepeatPlan)
    }

    func testSmartRepeatRecommendationCanApplySuggestedMethod() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-300),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Forum Ankara",
                priceTotal: 620,
                energyKWh: 40,
                socStart: 20,
                socEnd: 80
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-1_800),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Forum Ankara",
                priceTotal: 260,
                energyKWh: 33,
                socStart: 22,
                socEnd: 79
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-3_600),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Forum Ankara",
                priceTotal: 255,
                energyKWh: 32,
                socStart: 24,
                socEnd: 78
            )
        )

        let vm = AddChargeViewModel(environment: env)

        XCTAssertEqual(vm.smartRepeatPlan?.recommendation?.recommendedMethod, .publicAC)

        vm.applySmartRepeatRecommendation()

        XCTAssertEqual(vm.chargeMethod, .publicAC)
        XCTAssertFalse(vm.tariffPricePerKWh.isEmpty)
    }

    func testRepeatLastChargeHiddenWhenNoSessionExists() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        XCTAssertFalse(vm.canRepeatLastCharge)
    }

    func testFirstChargeCelebrationAppearsOnlyOnce() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstViewModel = AddChargeViewModel(environment: env, userDefaults: defaults)
        firstViewModel.totalPrice = "420"

        switch firstViewModel.save() {
        case .success(let payload):
            XCTAssertTrue(payload.showFirstChargeCelebration)
            XCTAssertNotNil(payload.sessionScore)
        case .failure:
            XCTFail("Ilk kayit basarili olmaliydi")
        }

        let secondViewModel = AddChargeViewModel(environment: env, userDefaults: defaults)
        secondViewModel.totalPrice = "380"

        switch secondViewModel.save() {
        case .success(let payload):
            XCTAssertFalse(payload.showFirstChargeCelebration)
            XCTAssertNotNil(payload.sessionScore)
        case .failure:
            XCTFail("Ikinci kayit basarili olmaliydi")
        }
    }

    func testFirstChargeCelebrationRespectsPersistedState() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.persistedCelebration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(true, forKey: "add_charge.first_charge.celebration_shown")

        let viewModel = AddChargeViewModel(environment: env, userDefaults: defaults)
        viewModel.totalPrice = "510"

        switch viewModel.save() {
        case .success(let payload):
            XCTAssertFalse(payload.showFirstChargeCelebration)
            XCTAssertNotNil(payload.sessionScore)
        case .failure:
            XCTFail("Kayit basarili olmaliydi")
        }
    }

    func testOperatorCatalogIncludesProvidedTurkiyeOperators() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vm = AddChargeViewModel(environment: env)

        let names = vm.operatorCatalog.map(\.name)
        XCTAssertEqual(names.count, 14)
        XCTAssertTrue(names.contains("ZES"))
        XCTAssertTrue(names.contains("Eşarj"))
        XCTAssertTrue(names.contains("Trugo"))
        XCTAssertTrue(names.contains("Ionity"))
    }

    func testFavoriteOperatorsPersistAcrossViewModelInstances() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let suiteName = "AddChargeViewModelTests.favoriteOperators.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstVM = AddChargeViewModel(environment: env, userDefaults: defaults)
        firstVM.toggleFavoriteOperator("Trugo")
        firstVM.toggleFavoriteOperator("zes")

        XCTAssertTrue(firstVM.isOperatorFavorite("ZES"))
        XCTAssertTrue(firstVM.isOperatorFavorite("Trugo"))
        XCTAssertEqual(firstVM.favoriteOperators.map(\.name), ["ZES", "Trugo"])

        let secondVM = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertEqual(secondVM.favoriteOperators.map(\.name), ["ZES", "Trugo"])
    }

    func testLocationCatalogUsesSelectedOperatorHistory() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-7_200),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 220,
                energyKWh: 18,
                socStart: 20,
                socEnd: 65
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-1_800),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Besiktas",
                priceTotal: 260,
                energyKWh: 22,
                socStart: 28,
                socEnd: 74
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicDC)
        vm.selectOperator("ZES")

        XCTAssertTrue(vm.locationCatalog.contains("Besiktas"))
        XCTAssertTrue(vm.locationCatalog.contains("Kadikoy"))
        XCTAssertEqual(vm.locationCatalog.first, "Besiktas")
    }

    func testSelectAndClearLocationUpdatesLocationName() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicAC)

        vm.selectLocation("Forum Ankara - A Blok")
        XCTAssertEqual(vm.locationName, "Forum Ankara - A Blok")

        vm.clearSelectedLocation()
        XCTAssertEqual(vm.locationName, "")
    }

    func testRefreshLiveInsightProducesComparisonForCurrentDraft() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-86_400),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 240,
                energyKWh: 30,
                socStart: 22,
                socEnd: 78
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicAC)
        vm.totalPrice = "360"
        vm.energyInput = "30"
        vm.refreshLiveInsightNow()

        XCTAssertEqual(vm.liveInsight?.pricePosition.kind, .expensive)
        XCTAssertNotNil(vm.liveInsight?.tlPerKWh.value)
    }

    func testRefreshLiveInsightSuggestsACForExpensiveDCDraft() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2026,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 16.5
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-172_800),
                chargeMethod: .publicAC,
                stationBrand: "Esarj",
                locationName: "Maslak",
                priceTotal: 200,
                energyKWh: 25,
                socStart: 30,
                socEnd: 78
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-86_400),
                chargeMethod: .publicAC,
                stationBrand: "Esarj",
                locationName: "Maslak",
                priceTotal: 216,
                energyKWh: 27,
                socStart: 24,
                socEnd: 80
            )
        )

        let vm = AddChargeViewModel(environment: env)
        vm.setChargeMethod(.publicDC)
        vm.totalPrice = "600"
        vm.energyInput = "40"
        vm.refreshLiveInsightNow()

        XCTAssertEqual(vm.liveInsight?.alternativeSuggestion?.recommendedMethod, .publicAC)
    }

    func testPredictiveDefaultsExposeQuickPresetsAndApplyThem() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-172_800),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 210,
                energyKWh: 30,
                socStart: 22,
                socEnd: 80,
                durationMin: 95
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-86_400),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 224,
                energyKWh: 32,
                socStart: 24,
                socEnd: 82,
                durationMin: 100
            )
        )

        let vm = AddChargeViewModel(environment: env)
        let preset = try XCTUnwrap(vm.predictiveDefaults?.quickPresets.first(where: { $0.kind == .publicACFavorite }))

        vm.applyQuickPreset(preset)

        XCTAssertEqual(vm.chargeMethod, .publicAC)
        XCTAssertEqual(vm.stationBrand, "ZES")
        XCTAssertEqual(vm.locationName, "Kadikoy")
        XCTAssertEqual(vm.durationMin, "100")
    }

    func testSmartFavoriteStationSuggestionsCanPrefillStationSelection() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-10_800),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 210,
                energyKWh: 30,
                socStart: 24,
                socEnd: 80,
                durationMin: 90,
                odometerKM: 1_000
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-7_200),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 224,
                energyKWh: 32,
                socStart: 22,
                socEnd: 81,
                durationMin: 96,
                odometerKM: 1_100
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-5_400),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 216,
                energyKWh: 31,
                socStart: 23,
                socEnd: 79,
                durationMin: 92,
                odometerKM: 1_145
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-3_600),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 390,
                energyKWh: 24,
                socStart: 18,
                socEnd: 75,
                durationMin: 40,
                odometerKM: 1_190
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-1_800),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 405,
                energyKWh: 25,
                socStart: 20,
                socEnd: 78,
                durationMin: 43,
                odometerKM: 1_280
            )
        )

        let vm = AddChargeViewModel(environment: env)
        let suggestion = try XCTUnwrap(vm.smartFavoriteStations?.suggestions.first(where: { $0.category == .mostUsed }))

        vm.applySmartFavoriteStation(suggestion)

        XCTAssertEqual(vm.stationBrand, "ZES")
        XCTAssertEqual(vm.locationName, "Kadikoy")
        XCTAssertEqual(vm.chargeMethod, .publicAC)
        XCTAssertFalse(vm.tariffPricePerKWh.isEmpty)
    }

    func testSkippedPlanRecommendationStaysHiddenAcrossInstances() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-7_200),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 420,
                energyKWh: 26,
                socStart: 18,
                socEnd: 82
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-3_600),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 430,
                energyKWh: 27,
                socStart: 16,
                socEnd: 84
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date().addingTimeInterval(-1_200),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 190,
                energyKWh: 18,
                socStart: 24,
                socEnd: 62
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let suiteName = "AddChargeViewModelTests.planSkip.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstVM = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertNotNil(firstVM.planRecommendation)

        firstVM.skipPlanRecommendation()
        XCTAssertNil(firstVM.planRecommendation)

        let secondVM = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertNil(secondVM.planRecommendation)
        XCTAssertNotNil(secondVM.activePlan)
    }

    func testSavePersistsContextTags() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let vm = AddChargeViewModel(environment: env)
        vm.totalPrice = "420"
        vm.toggleContextTag(.longRoad)
        vm.toggleContextTag(.coldWeather)

        assertSaveSucceeded(vm.save())

        let session = try XCTUnwrap(env.listChargingSessionsUseCase.execute(vehicleID: vehicle.id).first)
        XCTAssertEqual(session.contextTags, [.coldWeather, .longRoad])
    }

    func testDraftRestoresSelectedContextTags() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let suiteName = "AddChargeViewModelTests.contextDraft.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let writer = AddChargeViewModel(environment: env, userDefaults: defaults)
        writer.totalPrice = "380"
        writer.notes = "Uzun rota"
        writer.toggleContextTag(.longRoad)
        writer.toggleContextTag(.heavyTraffic)
        writer.persistDraft()

        let restored = AddChargeViewModel(environment: env, userDefaults: defaults)
        XCTAssertEqual(restored.notes, "Uzun rota")
        XCTAssertEqual(restored.selectedContextTags, [.heavyTraffic, .longRoad])
    }

    private func assertSaveSucceeded(
        _ result: AddChargeSaveResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            XCTFail("Kayit islemi basarili olmaliydi", file: file, line: line)
            return
        }
    }
}
#endif
