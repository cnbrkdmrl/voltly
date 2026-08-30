import Foundation

@MainActor
public final class ChargingOperatorsViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public private(set) var visibleOperators: [ChargingOperator] = []
    @Published public private(set) var hiddenOperators: [ChargingOperator] = []
    @Published public private(set) var message: String?

    private let repository: any ChargingOperatorRepository

    public init(repository: any ChargingOperatorRepository) {
        self.repository = repository
    }

    public func load() {
        do {
            try repository.seedIfNeeded()
            visibleOperators = try repository.visibleOperators()
            hiddenOperators = try repository.hiddenOperators()
            message = nil
        } catch {
            visibleOperators = []
            hiddenOperators = []
            message = error.localizedDescription
        }
    }

    public var filteredVisibleOperators: [ChargingOperator] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return visibleOperators }
        return visibleOperators.filter { $0.matches(query: query) }
    }

    public var filteredHiddenOperators: [ChargingOperator] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return hiddenOperators }
        return hiddenOperators.filter { $0.matches(query: query) }
    }

    public var favoriteOperators: [ChargingOperator] {
        filteredVisibleOperators.filter { $0.isFavorite }
    }

    public var nonFavoriteOperators: [ChargingOperator] {
        filteredVisibleOperators.filter { !$0.isFavorite }
    }

    public func toggleFavorite(_ operatorItem: ChargingOperator) {
        do {
            try repository.setFavorite(operatorCode: operatorItem.operatorCode, isFavorite: !operatorItem.isFavorite)
            load()
        } catch {
            message = error.localizedDescription
        }
    }

    public func hide(_ operatorItem: ChargingOperator) {
        do {
            try repository.setHidden(operatorCode: operatorItem.operatorCode, isHidden: true)
            load()
        } catch {
            message = error.localizedDescription
        }
    }

    public func unhide(_ operatorItem: ChargingOperator) {
        do {
            try repository.setHidden(operatorCode: operatorItem.operatorCode, isHidden: false)
            load()
        } catch {
            message = error.localizedDescription
        }
    }

    public func tierLabel(for tier: Int) -> String {
        "Tier \(tier)"
    }

    public func confidenceLabel(for confidence: String?) -> String? {
        guard let confidence else { return nil }
        switch confidence.lowercased() {
        case "high":
            return "Yüksek güven"
        case "medium":
            return "Orta güven"
        case "low":
            return "Düşük güven"
        default:
            return confidence
        }
    }

    public func stationCountLabel(for operatorItem: ChargingOperator) -> String? {
        guard let estimate = operatorItem.stationCountEstimate else { return nil }
        if let confidence = confidenceLabel(for: operatorItem.stationCountConfidence) {
            return "Yaklaşık \(estimate) istasyon • \(confidence)"
        }
        return "Yaklaşık \(estimate) istasyon"
    }
}
