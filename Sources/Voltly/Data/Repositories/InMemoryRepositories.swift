import Foundation

public final class InMemoryVehicleRepository: VehicleRepository {
    private var vehicles: [UUID: Vehicle] = [:]

    public init() {}

    public func fetchVehicles() throws -> [Vehicle] {
        vehicles.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetchActiveVehicle() throws -> Vehicle? {
        vehicles.values.first(where: { $0.isActive })
    }

    public func upsert(vehicle: Vehicle) throws {
        var copy = vehicle
        copy.updatedAt = .now
        vehicles[vehicle.id] = copy
    }

    public func delete(vehicleID: UUID) throws {
        vehicles.removeValue(forKey: vehicleID)
    }

    public func setActiveVehicle(id: UUID) throws {
        for key in vehicles.keys {
            var copy = vehicles[key]
            copy?.isActive = key == id
            copy?.updatedAt = .now
            if let copy {
                vehicles[key] = copy
            }
        }
    }
}

public final class InMemoryChargingSessionRepository: ChargingSessionRepository {
    private var sessions: [UUID: ChargingSession] = [:]

    public init() {}

    public func save(session: ChargingSession) throws {
        sessions[session.id] = session
    }

    public func delete(sessionID: UUID) throws {
        sessions.removeValue(forKey: sessionID)
    }

    public func fetchAll(vehicleID: UUID?) throws -> [ChargingSession] {
        sessions.values
            .filter { vehicleID == nil || $0.vehicleID == vehicleID }
            .sorted { $0.sessionDate > $1.sessionDate }
    }

    public func fetchRecent(vehicleID: UUID?, limit: Int) throws -> [ChargingSession] {
        Array(try fetchAll(vehicleID: vehicleID).prefix(limit))
    }

    public func fetchInRange(vehicleID: UUID?, from: Date, to: Date) throws -> [ChargingSession] {
        try fetchAll(vehicleID: vehicleID)
            .filter { $0.sessionDate >= from && $0.sessionDate <= to }
    }

    public func count(vehicleID: UUID) throws -> Int {
        try fetchAll(vehicleID: vehicleID).count
    }
}

public final class InMemorySettingsRepository: SettingsRepository {
    private var baseline = FuelBaselineSettings(
        fuelPricePerLiter: AppConstants.defaultFuelPricePerLiter,
        iceConsumptionLPer100Km: AppConstants.defaultICEConsumptionLPer100Km,
        currencyCode: AppConstants.defaultCurrencyCode,
        electricityPricePerKWh: AppConstants.defaultElectricityPricePerKWh
    )

    public init() {}

    public func getFuelBaseline() throws -> FuelBaselineSettings {
        baseline
    }

    public func saveFuelBaseline(_ settings: FuelBaselineSettings) throws {
        baseline = settings
    }
}

public final class InMemoryGoalRepository: GoalRepository {
    private var goals: [UserGoal] = []

    public init() {}

    public func fetchGoals() throws -> [UserGoal] {
        goals.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    public func saveGoals(_ goals: [UserGoal]) throws {
        self.goals = goals.sorted { $0.type.rawValue < $1.type.rawValue }
    }
}

public final class InMemoryChargingOperatorRepository: ChargingOperatorRepository {
    private struct Defaults {
        static let operators: [ChargingOperator] = [
            ChargingOperator(id: 1, operatorCode: "zes", displayName: "ZES", searchAliases: ["zes"], tier: 1, stationCountEstimate: 400, stationCountConfidence: "medium", supportsRoaming: true, sortOrder: 10),
            ChargingOperator(id: 2, operatorCode: "esarj", displayName: "Eşarj", searchAliases: ["esarj", "eşarj"], tier: 1, stationCountEstimate: 300, stationCountConfidence: "medium", supportsRoaming: true, sortOrder: 20),
            ChargingOperator(id: 3, operatorCode: "trugo", displayName: "Trugo", searchAliases: ["trugo"], tier: 1, stationCountEstimate: 350, stationCountConfidence: "medium", supportsRoaming: false, sortOrder: 30),
            ChargingOperator(id: 4, operatorCode: "sharz", displayName: "Sharz", searchAliases: ["sharz"], tier: 2, stationCountEstimate: 120, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 40),
            ChargingOperator(id: 5, operatorCode: "voltrun", displayName: "Voltrun", searchAliases: ["voltrun"], tier: 2, stationCountEstimate: 100, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 50),
            ChargingOperator(id: 6, operatorCode: "beefull", displayName: "Beefull", searchAliases: ["beefull"], tier: 2, stationCountEstimate: 80, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 60),
            ChargingOperator(id: 7, operatorCode: "wat_mobilite", displayName: "Wat Mobilite", searchAliases: ["wat", "wat mobilite"], tier: 2, stationCountEstimate: 90, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 70),
            ChargingOperator(id: 8, operatorCode: "rhg_enerturk", displayName: "RHG Enertürk", searchAliases: ["rhg", "enerturk"], tier: 3, stationCountEstimate: 60, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 80),
            ChargingOperator(id: 9, operatorCode: "astor_sarj", displayName: "Astor Şarj", searchAliases: ["astor", "astor sarj"], tier: 3, stationCountEstimate: 55, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 90),
            ChargingOperator(id: 10, operatorCode: "powersarj", displayName: "Powerşarj", searchAliases: ["power sarj", "powersarj"], tier: 3, stationCountEstimate: 70, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 100),
            ChargingOperator(id: 11, operatorCode: "chargeiq", displayName: "ChargeIQ", searchAliases: ["chargeiq"], tier: 3, stationCountEstimate: 40, stationCountConfidence: "low", supportsRoaming: nil, sortOrder: 110),
            ChargingOperator(id: 12, operatorCode: "electrip", displayName: "Electrip", searchAliases: ["electrip"], tier: 2, stationCountEstimate: 140, stationCountConfidence: "medium", supportsRoaming: true, sortOrder: 120),
            ChargingOperator(id: 13, operatorCode: "greenway", displayName: "GreenWay", searchAliases: ["greenway"], tier: 2, stationCountEstimate: 100, stationCountConfidence: "low", supportsRoaming: true, sortOrder: 130),
            ChargingOperator(id: 14, operatorCode: "ionity", displayName: "Ionity", searchAliases: ["ionity"], tier: 1, stationCountEstimate: 25, stationCountConfidence: "medium", supportsRoaming: true, sortOrder: 140)
        ]
    }

    private var operators: [ChargingOperator] = Defaults.operators

    public init() {}

    public func visibleOperators() throws -> [ChargingOperator] {
        operators
            .filter { $0.isActive && !$0.isHidden }
            .sorted(by: Self.operatorSort)
    }

    public func favoriteOperators() throws -> [ChargingOperator] {
        try visibleOperators().filter { $0.isFavorite }
    }

    public func hiddenOperators() throws -> [ChargingOperator] {
        operators
            .filter { $0.isHidden }
            .sorted(by: Self.operatorSort)
    }

    public func `operator`(byCode code: String) throws -> ChargingOperator? {
        let normalized = Self.normalize(code)
        return operators.first { Self.normalize($0.operatorCode) == normalized }
    }

    public func seedIfNeeded() throws {
        // In-memory repository always starts seeded.
    }

    public func setFavorite(operatorCode: String, isFavorite: Bool) throws {
        guard let index = operators.firstIndex(where: { Self.normalize($0.operatorCode) == Self.normalize(operatorCode) }) else {
            return
        }

        let operatorItem = operators[index]
        let nextOrder: Int? = isFavorite ? ((operators.compactMap(\.favoriteOrder).max() ?? 0) + 1) : nil

        operators[index] = ChargingOperator(
            id: operatorItem.id,
            operatorCode: operatorItem.operatorCode,
            displayName: operatorItem.displayName,
            searchAliases: operatorItem.searchAliases,
            countryCode: operatorItem.countryCode,
            tier: operatorItem.tier,
            stationCountEstimate: operatorItem.stationCountEstimate,
            stationCountConfidence: operatorItem.stationCountConfidence,
            supportsRoaming: operatorItem.supportsRoaming,
            appRequired: operatorItem.appRequired,
            isActive: operatorItem.isActive,
            isFavorite: isFavorite,
            favoriteOrder: nextOrder,
            isHidden: operatorItem.isHidden,
            sortOrder: operatorItem.sortOrder,
            sourceBasis: operatorItem.sourceBasis,
            notes: operatorItem.notes,
            createdAt: operatorItem.createdAt,
            updatedAt: operatorItem.updatedAt
        )
    }

    public func setHidden(operatorCode: String, isHidden: Bool) throws {
        guard let index = operators.firstIndex(where: { Self.normalize($0.operatorCode) == Self.normalize(operatorCode) }) else {
            return
        }

        let operatorItem = operators[index]
        operators[index] = ChargingOperator(
            id: operatorItem.id,
            operatorCode: operatorItem.operatorCode,
            displayName: operatorItem.displayName,
            searchAliases: operatorItem.searchAliases,
            countryCode: operatorItem.countryCode,
            tier: operatorItem.tier,
            stationCountEstimate: operatorItem.stationCountEstimate,
            stationCountConfidence: operatorItem.stationCountConfidence,
            supportsRoaming: operatorItem.supportsRoaming,
            appRequired: operatorItem.appRequired,
            isActive: operatorItem.isActive,
            isFavorite: isHidden ? false : operatorItem.isFavorite,
            favoriteOrder: isHidden ? nil : operatorItem.favoriteOrder,
            isHidden: isHidden,
            sortOrder: operatorItem.sortOrder,
            sourceBasis: operatorItem.sourceBasis,
            notes: operatorItem.notes,
            createdAt: operatorItem.createdAt,
            updatedAt: operatorItem.updatedAt
        )
    }

    private static func operatorSort(lhs: ChargingOperator, rhs: ChargingOperator) -> Bool {
        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite && !rhs.isFavorite
        }

        let lhsFavoriteOrderRank = lhs.favoriteOrder == nil ? Int.max : (lhs.favoriteOrder ?? 0)
        let rhsFavoriteOrderRank = rhs.favoriteOrder == nil ? Int.max : (rhs.favoriteOrder ?? 0)
        if lhsFavoriteOrderRank != rhsFavoriteOrderRank {
            return lhsFavoriteOrderRank < rhsFavoriteOrderRank
        }

        if lhs.tier != rhs.tier {
            return lhs.tier < rhs.tier
        }

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
