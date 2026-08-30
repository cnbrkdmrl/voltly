import Foundation

#if canImport(WidgetKit) && os(iOS)
import WidgetKit
#endif

public struct WidgetMonthlySummary: Codable, Equatable {
    public let updatedAt: Date
    public let currencyCode: String
    public let monthlyTotalCost: Double
    public let monthlyTotalEnergy: Double
    public let tlPer100Km: Double?

    public init(
        updatedAt: Date,
        currencyCode: String,
        monthlyTotalCost: Double,
        monthlyTotalEnergy: Double,
        tlPer100Km: Double?
    ) {
        self.updatedAt = updatedAt
        self.currencyCode = currencyCode
        self.monthlyTotalCost = monthlyTotalCost
        self.monthlyTotalEnergy = monthlyTotalEnergy
        self.tlPer100Km = tlPer100Km
    }
}

public enum WidgetSharedStore {
    private enum Keys {
        static let monthlySummary = "widget.monthly.summary"
    }

    public static func save(summary: WidgetMonthlySummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: Keys.monthlySummary)
        reloadWidgetTimelines()
    }

    public static func loadSummary() -> WidgetMonthlySummary? {
        guard let data = defaults.data(forKey: Keys.monthlySummary) else { return nil }
        return try? JSONDecoder().decode(WidgetMonthlySummary.self, from: data)
    }

    public static func save(snapshot: DashboardSnapshot) {
        save(summary: makeSummary(from: snapshot))
    }

    public static func makeSummary(from snapshot: DashboardSnapshot) -> WidgetMonthlySummary {
        WidgetMonthlySummary(
            updatedAt: .now,
            currencyCode: snapshot.currencyCode,
            monthlyTotalCost: snapshot.monthlyTotalCost,
            monthlyTotalEnergy: snapshot.monthlyTotalEnergy,
            tlPer100Km: snapshot.tlPer100Km?.value
        )
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.widgetAppGroupIdentifier) ?? .standard
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
