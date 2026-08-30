import SwiftUI

public struct ChargeHabitMetricsCard: View {
    private let summary: ChargeHabitMetricsSummary?

    public init(summary: ChargeHabitMetricsSummary?) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Şarj Alışkanlığı Özeti")
                .font(.headline)

            if let summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(socInsightText(summary))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summary.rangeComment)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: gridColumns, spacing: 8) {
                    metricTile(
                        title: "Ortalama Şarj Yüzdesi",
                        value: socRangeText(summary)
                    )
                    metricTile(
                        title: "Ortalama Şarj Süresi",
                        value: durationText(summary.averageDurationMin)
                    )
                    metricTile(
                        title: "Ortalama Enerji",
                        value: energyText(summary.averageEnergyKWh)
                    )
                }

                Label(summary.recommendedRangeText, systemImage: "bolt.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.publicACColor)

                if let bestRangeInsight = summary.bestRangeInsight {
                    Label(bestRangeInsight, systemImage: "leaf")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                EmptyInfoCard(
                    title: "Alışkanlık özeti için veri yok",
                    subtitle: "Yüzde, süre ve enerji bilgisi olan şarj kayıtları eklendikçe burada görünür.",
                    iconName: "waveform.path.ecg.text.page"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private func socInsightText(_ summary: ChargeHabitMetricsSummary) -> String {
        guard let start = summary.averageSOCStart,
              let end = summary.averageSOCEnd else {
            return "Ortalama şarj yüzdesi için yeterli veri yok."
        }
        return "Ortalama %\(Int(start.rounded())) → %\(Int(end.rounded())) arası şarj ediyorsun."
    }

    private func socRangeText(_ summary: ChargeHabitMetricsSummary) -> String {
        guard let start = summary.averageSOCStart,
              let end = summary.averageSOCEnd else {
            return "Veri yok"
        }
        return "%\(Int(start.rounded())) → %\(Int(end.rounded()))"
    }

    private func durationText(_ minutes: Double?) -> String {
        guard let minutes else { return "Veri yok" }
        return "\(Int(minutes.rounded())) dk"
    }

    private func energyText(_ energy: Double?) -> String {
        guard let energy else { return "Veri yok" }
        return "\(NumberFormatting.oneDecimal(energy)) kWh"
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
struct ChargeHabitMetricsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChargeHabitMetricsCard(
                summary: ChargeHabitMetricsSummary(
                    averageSOCStart: 28.2,
                    averageSOCEnd: 81.6,
                    averageDurationMin: 54.0,
                    averageEnergyKWh: 23.7,
                    rangeComment: "Aralığın kabul edilebilir. Bir miktar daha dar pencereyle verimi daha kolay koruyabilirsin.",
                    recommendedRangeText: "Verimli pencere çoğu kullanımda yaklaşık %15-%80 bandında kalıyor.",
                    bestRangeInsight: "En verimli şarj aralığın genelde %22-%78 bandında toparlanıyor."
                )
            )

            ChargeHabitMetricsCard(summary: nil)
        }
        .padding()
    }
}
#endif
