import Foundation

public struct ChargingOperator: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let operatorCode: String
    public let displayName: String
    public let searchAliases: [String]
    public let countryCode: String
    public let tier: Int
    public let stationCountEstimate: Int?
    public let stationCountConfidence: String?
    public let supportsRoaming: Bool?
    public let appRequired: Bool
    public let isActive: Bool
    public let isFavorite: Bool
    public let favoriteOrder: Int?
    public let isHidden: Bool
    public let sortOrder: Int
    public let sourceBasis: String?
    public let notes: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: Int64,
        operatorCode: String,
        displayName: String,
        searchAliases: [String],
        countryCode: String = "TR",
        tier: Int = 3,
        stationCountEstimate: Int? = nil,
        stationCountConfidence: String? = nil,
        supportsRoaming: Bool? = nil,
        appRequired: Bool = true,
        isActive: Bool = true,
        isFavorite: Bool = false,
        favoriteOrder: Int? = nil,
        isHidden: Bool = false,
        sortOrder: Int = 9999,
        sourceBasis: String? = nil,
        notes: String? = nil,
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.id = id
        self.operatorCode = operatorCode
        self.displayName = displayName
        self.searchAliases = searchAliases
        self.countryCode = countryCode
        self.tier = tier
        self.stationCountEstimate = stationCountEstimate
        self.stationCountConfidence = stationCountConfidence
        self.supportsRoaming = supportsRoaming
        self.appRequired = appRequired
        self.isActive = isActive
        self.isFavorite = isFavorite
        self.favoriteOrder = favoriteOrder
        self.isHidden = isHidden
        self.sortOrder = sortOrder
        self.sourceBasis = sourceBasis
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func matches(query: String) -> Bool {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        guard !normalizedQuery.isEmpty else { return true }

        if operatorCode
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .contains(normalizedQuery) {
            return true
        }

        if displayName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .contains(normalizedQuery) {
            return true
        }

        return searchAliases.contains { alias in
            alias
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .contains(normalizedQuery)
        }
    }
}
