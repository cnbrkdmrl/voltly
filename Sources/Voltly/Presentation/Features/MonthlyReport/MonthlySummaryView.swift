import SwiftUI

public struct MonthlySummaryView: View {
    public enum Style {
        case appCard
        case shareCard
    }

    private let summary: MonthlyEVReportSummary?
    private let style: Style

    public init(
        summary: MonthlyEVReportSummary?,
        style: Style = .appCard
    ) {
        self.summary = summary
        self.style = style
    }

    public var body: some View {
        Group {
            if let summary {
                content(summary)
            } else {
                EmptyInfoCard(
                    title: "Aylık özet için veri yok",
                    subtitle: "Bu ay birkaç şarj kaydı sonrası özet burada görünür.",
                    iconName: "calendar.badge.exclamationmark"
                )
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func content(_ summary: MonthlyEVReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aylık Özet")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryTextColor)
                    Text(summary.monthTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(secondaryTextColor)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bolt.car.fill")
                        .font(.caption.weight(.semibold))
                    Text("Voltly")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tagBackgroundColor)
                .clipShape(Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(NumberFormatting.currency(summary.totalCost, code: summary.currencyCode))
                    .font(mainAmountFont)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("toplam harcama")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
            }

            LazyVGrid(columns: metricColumns, spacing: 10) {
                metricTile(
                    title: "Toplam Enerji",
                    value: NumberFormatting.kWh(summary.totalEnergyKWh)
                )
                metricTile(
                    title: "Ort. TL/kWh",
                    value: summary.averageTLPerKWh.map {
                        NumberFormatting.tlPerKWh($0, currencyCode: summary.currencyCode)
                    } ?? "Veri yok"
                )
                metricTile(
                    title: "Ort. TL/100km",
                    value: summary.tlPer100Km.map {
                        NumberFormatting.currency($0.value, code: summary.currencyCode)
                    } ?? "Veri yok"
                )
                metricTile(
                    title: "Seans",
                    value: "\(summary.sessionCount)"
                )
            }

            distributionSection(summary.chargeDistribution)

            if let savingsLine = savingsLine(summary) {
                Text(savingsLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(savingsColor)
                    .padding(.top, 2)
            }
        }
    }

    private func distributionSection(_ distribution: MonthlyChargeDistribution) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AC / DC Dağılımı")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)

            HStack(spacing: 8) {
                distributionPill(label: "Ev", value: distribution.homeRatio, color: AppTheme.homeColor)
                distributionPill(label: "AC", value: distribution.acRatio, color: AppTheme.publicACColor)
                distributionPill(label: "DC", value: distribution.dcRatio, color: AppTheme.publicDCColor)
            }
        }
    }

    private func distributionPill(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) %\(Int(value.rounded()))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryTextColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(tileBackgroundColor)
        .clipShape(Capsule())
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(tileBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func savingsLine(_ summary: MonthlyEVReportSummary) -> String? {
        guard let percent = summary.gasolineSavingsPercent else { return nil }
        if let amount = summary.gasolineSavingsAmount, amount > 0 {
            return "Benzin eşdeğerine göre yaklaşık \(NumberFormatting.percent(percent)) avantaj (\(NumberFormatting.currency(amount, code: summary.currencyCode)) / 100 km)."
        }
        return "Benzin eşdeğerine göre yaklaşık \(NumberFormatting.percent(percent)) avantaj."
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var cardPadding: CGFloat {
        style == .shareCard ? 22 : UIConstants.cardInnerPadding
    }

    private var cornerRadius: CGFloat {
        style == .shareCard ? 26 : UIConstants.cardCornerRadius
    }

    @ViewBuilder
    private var backgroundView: some View {
        if style == .shareCard {
            LinearGradient(
                colors: [
                    AppTheme.heroBackground,
                    AppTheme.publicACColor.opacity(0.82),
                    AppTheme.dcAccent.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            AppTheme.surface
        }
    }

    private var primaryTextColor: Color {
        style == .shareCard ? .white : .primary
    }

    private var secondaryTextColor: Color {
        style == .shareCard ? .white.opacity(0.86) : .secondary
    }

    private var tagBackgroundColor: Color {
        style == .shareCard ? Color.white.opacity(0.14) : AppTheme.overlaySurface
    }

    private var tileBackgroundColor: Color {
        style == .shareCard ? Color.white.opacity(0.12) : AppTheme.overlaySurface
    }

    private var savingsColor: Color {
        style == .shareCard ? Color.white.opacity(0.96) : AppTheme.homeColor
    }

    private var mainAmountFont: Font {
        style == .shareCard
            ? .system(size: 42, weight: .black, design: .rounded)
            : .title2.weight(.bold)
    }
}

#if DEBUG
struct MonthlySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 14) {
            MonthlySummaryView(
                summary: MonthlyEVReportSummary(
                    month: Date(),
                    monthTitle: "Mart 2026",
                    totalEnergyKWh: 241.6,
                    sessionCount: 12,
                    totalCost: 2_934,
                    averageTLPerKWh: 12.14,
                    tlPer100Km: .exact(224.7),
                    chargeDistribution: MonthlyChargeDistribution(
                        homeRatio: 24,
                        acRatio: 41,
                        dcRatio: 35
                    ),
                    gasolineSavingsPercent: 32,
                    gasolineSavingsAmount: 108,
                    currencyCode: "TRY"
                ),
                style: .appCard
            )

            MonthlySummaryView(
                summary: MonthlyEVReportSummary(
                    month: Date(),
                    monthTitle: "Mart 2026",
                    totalEnergyKWh: 241.6,
                    sessionCount: 12,
                    totalCost: 2_934,
                    averageTLPerKWh: 12.14,
                    tlPer100Km: .exact(224.7),
                    chargeDistribution: MonthlyChargeDistribution(
                        homeRatio: 24,
                        acRatio: 41,
                        dcRatio: 35
                    ),
                    gasolineSavingsPercent: 32,
                    gasolineSavingsAmount: 108,
                    currencyCode: "TRY"
                ),
                style: .shareCard
            )
            .frame(width: 320, height: 570)
        }
        .padding()
    }
}
#endif
