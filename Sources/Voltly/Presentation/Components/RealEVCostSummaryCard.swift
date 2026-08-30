import SwiftUI

public struct RealEVCostSummaryCard: View {
    private let summary: RealEVCostSummary?
    private let fallbackMessage: String?

    public init(summary: RealEVCostSummary?, fallbackMessage: String? = nil) {
        self.summary = summary
        self.fallbackMessage = fallbackMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gerçek sürüş maliyeti")
                .font(.headline)

            if let summary {
                HStack(spacing: 10) {
                    metricTile(
                        title: "Ortalama",
                        value: NumberFormatting.currency(summary.averagePer100Km, code: summary.currencyCode),
                        accent: AppTheme.publicACColor
                    )
                    metricTile(
                        title: "En iyi",
                        value: NumberFormatting.currency(summary.bestPer100Km, code: summary.currencyCode),
                        accent: AppTheme.homeColor
                    )
                    metricTile(
                        title: "En kötü",
                        value: NumberFormatting.currency(summary.worstPer100Km, code: summary.currencyCode),
                        accent: AppTheme.publicDCColor
                    )
                }

                if let percent = summary.gasolineSavingsPercent {
                    if percent > 0 {
                        Text("Benzine göre \(NumberFormatting.percent(percent)) daha ucuz")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("Benzine göre belirgin bir tasarruf görünmüyor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Benzin kıyası için Ayarlar'da benzin fiyatı ve tüketim değerini gir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(summary.sampleCount) sürüş segmenti ile hesaplandı")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                EmptyInfoCard(
                    title: "Henüz yeterli veri yok",
                    subtitle: fallbackMessage ?? "Gerçek maliyet için en az 2 odometre kaydı gerekli.",
                    iconName: "gauge.with.needle"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private func metricTile(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("/ 100 km")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
struct RealEVCostSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            RealEVCostSummaryCard(
                summary: RealEVCostSummary(
                    averagePer100Km: 192,
                    bestPer100Km: 130,
                    worstPer100Km: 260,
                    gasolineSavingsPercent: 48,
                    currencyCode: "TRY",
                    sampleCount: 7
                )
            )

            RealEVCostSummaryCard(summary: nil)
        }
        .padding()
    }
}
#endif
