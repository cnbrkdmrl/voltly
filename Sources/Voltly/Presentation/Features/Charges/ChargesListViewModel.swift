import Foundation

public enum ChargeDateFilter: String, CaseIterable, Identifiable {
    case all
    case month
    case year

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "Tum Zaman"
        case .month:
            return "Aylik"
        case .year:
            return "Yillik"
        }
    }
}

public enum ChargeSortOption: String, CaseIterable, Identifiable {
    case newest
    case mostExpensive
    case cheapest
    case highestEnergy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newest: return "En yeni"
        case .mostExpensive: return "En pahalı"
        case .cheapest: return "En ucuz"
        case .highestEnergy: return "En fazla enerji"
        }
    }
}

@MainActor
public final class ChargesListViewModel: ObservableObject {
    @Published public private(set) var sessions: [ChargingSession] = []
    @Published public private(set) var sessionScores: [UUID: ChargeSessionScoreReport] = [:]
    @Published public private(set) var allSessionCount: Int = 0
    @Published public private(set) var latestRealtimeMetricsUpdate: ChargeMetricsRealtimeUpdate?
    @Published public private(set) var errorMessage: String?
    @Published public var selectedMethod: ChargeMethod?
    @Published public var selectedDateFilter: ChargeDateFilter = .all
    @Published public var selectedSort: ChargeSortOption = .newest

    private let environment: AppEnvironment
    private var allSessions: [ChargingSession] = []

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func load() {
        do {
            let all = try environment.listChargingSessionsUseCase.execute()
            allSessions = all
            try recalculateVisibleState()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func delete(_ session: ChargingSession) {
        do {
            let realtimeUpdate = try environment.deleteChargingSessionUseCase.execute(id: session.id)
            latestRealtimeMetricsUpdate = realtimeUpdate
            allSessions.removeAll { $0.id == session.id }
            try recalculateVisibleState()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func makeEditViewModel(for session: ChargingSession) -> AddChargeViewModel {
        AddChargeViewModel(environment: environment, editingSession: session)
    }

    public func makeMapViewModel() -> ChargeMapViewModel {
        ChargeMapViewModel(environment: environment)
    }

    private func recalculateVisibleState() throws {
        allSessionCount = allSessions.count
        let calendar = Calendar.current
        let now = Date()

        var filtered = allSessions
        if let selectedMethod {
            filtered = filtered.filter { $0.chargeMethod == selectedMethod }
        }

        switch selectedDateFilter {
        case .all:
            break
        case .month:
            filtered = filtered.filter { calendar.isDate($0.sessionDate, equalTo: now, toGranularity: .month) }
        case .year:
            filtered = filtered.filter { calendar.isDate($0.sessionDate, equalTo: now, toGranularity: .year) }
        }

        switch selectedSort {
        case .newest:
            filtered.sort { $0.sessionDate > $1.sessionDate }
        case .mostExpensive:
            filtered.sort { $0.priceTotal > $1.priceTotal }
        case .cheapest:
            filtered.sort { $0.priceTotal < $1.priceTotal }
        case .highestEnergy:
            filtered.sort { ($0.energyKWh ?? 0) > ($1.energyKWh ?? 0) }
        }

        sessions = filtered
        let vehiclesByID = try Dictionary(
            uniqueKeysWithValues: environment.vehicleRepository.fetchVehicles().map { ($0.id, $0) }
        )
        sessionScores = environment.chargeSessionScoringService.scoreReports(
            sessions: filtered,
            vehiclesByID: vehiclesByID
        )
    }
}
