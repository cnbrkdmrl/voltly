import SwiftUI

public struct AdvancedChargeAnalysisCard: View {
    private let report: ChargeInsightReport?

    public init(report: ChargeInsightReport?) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gelişmiş Analiz")
                .font(.headline)

            if let report {
                VStack(alignment: .leading, spacing: 10) {
                    ratioRow(title: "Ev / AC / DC", report: report)
                    Divider()
                    summaryGrid(title: "Genel Ortalama", summary: report.overall, currencyCode: report.currencyCode)
                    Divider()
                    summaryGrid(title: "Son 5 Şarj", summary: report.lastFiveSessions, currencyCode: report.currencyCode)
                    Divider()
                    summaryGrid(title: "Son 30 Gün", summary: report.lastThirtyDays, currencyCode: report.currencyCode)
                    Divider()
                    deltaSection(report: report)
                }
            } else {
                Text("Gelişmiş analiz için yeterli veri yok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func ratioRow(title: String, report: ChargeInsightReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                ratioPill(title: "Ev", value: report.usageRatios.homeRatio.value, confidence: report.usageRatios.homeRatio.confidence)
                ratioPill(title: "AC", value: report.usageRatios.acRatio.value, confidence: report.usageRatios.acRatio.confidence)
                ratioPill(title: "DC", value: report.usageRatios.dcRatio.value, confidence: report.usageRatios.dcRatio.confidence)
            }
        }
    }

    @ViewBuilder
    private func summaryGrid(
        title: String,
        summary: ChargeInsightWindowSummary,
        currencyCode: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(summary.sessionCount) seans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                metricBox(
                    title: "TL/kWh",
                    value: summary.averageTLPerKWh.value.map { NumberFormatting.tlPerKWh($0, currencyCode: currencyCode) } ?? "--",
                    confidence: summary.averageTLPerKWh.confidence
                )
                metricBox(
                    title: "TL/100 km",
                    value: summary.averageTLPer100Km.value.map { NumberFormatting.currency($0, code: currencyCode) } ?? "--",
                    confidence: summary.averageTLPer100Km.confidence
                )
                metricBox(
                    title: "Enerji",
                    value: summary.averageEnergyKWh.value.map(NumberFormatting.kWh) ?? "--",
                    confidence: summary.averageEnergyKWh.confidence
                )
                metricBox(
                    title: "Süre",
                    value: summary.averageDurationMinutes.value.map { "\(Int($0.rounded())) dk" } ?? "--",
                    confidence: summary.averageDurationMinutes.confidence
                )
                metricBox(
                    title: "Başlangıç SOC",
                    value: summary.averageStartSOC.value.map { "%\(Int($0.rounded()))" } ?? "--",
                    confidence: summary.averageStartSOC.confidence
                )
                metricBox(
                    title: "Bitiş SOC",
                    value: summary.averageEndSOC.value.map { "%\(Int($0.rounded()))" } ?? "--",
                    confidence: summary.averageEndSOC.confidence
                )
            }
        }
    }

    @ViewBuilder
    private func deltaSection(report: ChargeInsightReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Önceki 30 Gün Farkı")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                deltaBox(title: "TL/kWh", metric: report.previousThirtyDayDelta.averageTLPerKWhDelta, formatter: { NumberFormatting.tlPerKWh($0, currencyCode: report.currencyCode) })
                deltaBox(title: "TL/100 km", metric: report.previousThirtyDayDelta.averageTLPer100KmDelta, formatter: { NumberFormatting.currency($0, code: report.currencyCode) })
                deltaBox(title: "Enerji", metric: report.previousThirtyDayDelta.averageEnergyKWhDelta, formatter: NumberFormatting.kWh)
                deltaBox(title: "Süre", metric: report.previousThirtyDayDelta.averageDurationMinutesDelta, formatter: { "\(Int($0.rounded())) dk" })
            }
        }
    }

    private func ratioPill(title: String, value: Double?, confidence: DataConfidenceScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(value.map { "%\(Int($0.rounded()))" } ?? "--")
                .font(.subheadline.weight(.bold))
            confidenceBadge(confidence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricBox(title: String, value: String, confidence: DataConfidenceScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
            confidenceBadge(confidence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func deltaBox(
        title: String,
        metric: InsightMetric<Double>,
        formatter: (Double) -> String
    ) -> some View {
        let value = metric.value ?? 0
        let prefix = metric.value == nil ? "" : (value >= 0 ? "+" : "")

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(metric.value.map { "\(prefix)\(formatter($0))" } ?? "--")
                .font(.subheadline.weight(.bold))
            confidenceBadge(metric.confidence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func confidenceBadge(_ confidence: DataConfidenceScore) -> some View {
        Text("\(confidenceLabel(confidence)) • \(confidence.score)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor(confidence).opacity(0.14))
            .foregroundStyle(confidenceColor(confidence))
            .clipShape(Capsule())
    }

    private func confidenceLabel(_ confidence: DataConfidenceScore) -> String {
        switch confidence.source {
        case .real:
            return "Gerçek veri"
        case .mixed:
            return "Karma"
        case .estimated:
            return "Tahmini"
        case .unavailable:
            return "Veri yok"
        }
    }

    private func confidenceColor(_ confidence: DataConfidenceScore) -> Color {
        switch confidence.source {
        case .real:
            return AppTheme.homeColor
        case .mixed:
            return .orange
        case .estimated:
            return AppTheme.publicACColor
        case .unavailable:
            return .secondary
        }
    }
}
