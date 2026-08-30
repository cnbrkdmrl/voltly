import SwiftUI

public struct CostAnalysisCard: View {
    private let analysis: CostAnalysisSummary?

    public init(analysis: CostAnalysisSummary?) {
        self.analysis = analysis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Maliyet Analizi")
                .font(.headline)

            if let analysis {
                entryRow(
                    title: "En ucuz şarj",
                    entry: analysis.cheapest,
                    accent: AppTheme.homeColor
                )
                Divider()
                entryRow(
                    title: "En pahalı şarj",
                    entry: analysis.mostExpensive,
                    accent: AppTheme.publicDCColor
                )
            } else {
                EmptyInfoCard(
                    title: "Maliyet analizi için yeterli veri yok",
                    subtitle: "Enerji değeri 0 olan kayıtlar hesaplamaya dahil edilmez.",
                    iconName: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func entryRow(title: String, entry: CostAnalysisEntry, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(entry.location)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(entry.method.titleTR)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.method.uiColor)

            Text(NumberFormatting.tlPerKWh(entry.tlPerKWh))
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
        }
    }
}

#if DEBUG
struct CostAnalysisCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            CostAnalysisCard(
                analysis: CostAnalysisSummary(
                    cheapest: CostAnalysisEntry(
                        location: "Ev Wallbox • Garaj",
                        method: .home,
                        tlPerKWh: 4.2
                    ),
                    mostExpensive: CostAnalysisEntry(
                        location: "Lumicle • Gönen",
                        method: .publicDC,
                        tlPerKWh: 11.6
                    )
                )
            )

            CostAnalysisCard(analysis: nil)
        }
        .padding()
    }
}
#endif
