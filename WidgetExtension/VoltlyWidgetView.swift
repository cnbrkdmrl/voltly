import SwiftUI
import WidgetKit
import VoltlyKit

struct VoltlyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VoltlyWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Voltly")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Bu Ay")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(NumberFormatting.currency(entry.monthlyTotalCost, code: entry.currencyCode))
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            Text("⚡ \(energyText)")
                .font(.caption)
                .lineLimit(1)
            Text("🚗 \(costPer100Text)")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var mediumLayout: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Voltly")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Bu Ay")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(NumberFormatting.currency(entry.monthlyTotalCost, code: entry.currencyCode))
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if entry.isPlaceholder {
                    Text("Veriler uygulamadan senkronize edilir")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 8) {
                metricRow(icon: "⚡", value: energyText)
                metricRow(icon: "🚗", value: costPer100Text)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private func metricRow(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var energyText: String {
        "\(Int(entry.monthlyTotalEnergy.rounded())) kWh"
    }

    private var costPer100Text: String {
        guard let tlPer100Km = entry.tlPer100Km else { return "Veri yok" }
        return "\(NumberFormatting.currency(tlPer100Km, code: entry.currencyCode)) / 100 km"
    }
}
