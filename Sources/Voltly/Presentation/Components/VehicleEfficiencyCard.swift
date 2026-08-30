import SwiftUI

public struct VehicleEfficiencyCard: View {
    private let summary: VehicleEfficiencySummary?
    private let analysisConfidence: AnalysisConfidenceReport?

    public init(
        summary: VehicleEfficiencySummary?,
        analysisConfidence: AnalysisConfidenceReport? = nil
    ) {
        self.summary = summary
        self.analysisConfidence = analysisConfidence
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Araç Verimliliği")
                .font(.headline)

            if let summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.headline)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.supportingText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let analysisConfidence {
                    AnalysisConfidenceView(confidence: analysisConfidence)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text("\(NumberFormatting.oneDecimal(summary.averageEnergyPer100Km.value)) kWh / 100km")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    EstimationBadge(isEstimated: summary.averageEnergyPer100Km.isEstimated)
                }
            } else {
                EmptyInfoCard(
                    title: "Ortalama tüketim için veri yok",
                    subtitle: "En az 2 kayıtta km ve enerji bilgisi gerekli.",
                    iconName: "gauge.medium"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct VehicleEfficiencyCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            VehicleEfficiencyCard(
                summary: VehicleEfficiencySummary(
                    averageEnergyPer100Km: .exact(17.8),
                    confidence: DataConfidenceScore(
                        score: 88,
                        source: .real,
                        sampleCount: 4,
                        exactSampleCount: 4,
                        estimatedSampleCount: 0,
                        missingSampleCount: 0
                    ),
                    headline: "Tüketim görünümün gerçek sürüş verinle hizalı",
                    supportingText: "kWh/100 km sonucu tutarlı km verisiyle doğrulandı."
                )
            )
            VehicleEfficiencyCard(summary: nil)
        }
        .padding()
    }
}
#endif
