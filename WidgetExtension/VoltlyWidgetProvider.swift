import Foundation
import WidgetKit
import VoltlyKit

struct VoltlyWidgetEntry: TimelineEntry {
    let date: Date
    let currencyCode: String
    let monthlyTotalCost: Double
    let monthlyTotalEnergy: Double
    let tlPer100Km: Double?
    let isPlaceholder: Bool
}

struct VoltlyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoltlyWidgetEntry {
        sampleEntry(isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (VoltlyWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoltlyWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> VoltlyWidgetEntry {
        guard let summary = WidgetSharedStore.loadSummary() else {
            return sampleEntry(isPlaceholder: false)
        }

        return VoltlyWidgetEntry(
            date: summary.updatedAt,
            currencyCode: summary.currencyCode,
            monthlyTotalCost: summary.monthlyTotalCost,
            monthlyTotalEnergy: summary.monthlyTotalEnergy,
            tlPer100Km: summary.tlPer100Km,
            isPlaceholder: false
        )
    }

    private func sampleEntry(isPlaceholder: Bool) -> VoltlyWidgetEntry {
        VoltlyWidgetEntry(
            date: .now,
            currencyCode: "TRY",
            monthlyTotalCost: 2726,
            monthlyTotalEnergy: 253,
            tlPer100Km: 192,
            isPlaceholder: isPlaceholder
        )
    }
}
