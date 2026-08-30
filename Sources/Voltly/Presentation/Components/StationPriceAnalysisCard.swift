import SwiftUI

public struct StationPriceAnalysisCard: View {
    private let operatorAverages: [OperatorPriceAverage]
    private let currencyCode: String

    public init(operatorAverages: [OperatorPriceAverage], currencyCode: String) {
        self.operatorAverages = operatorAverages
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Şarj İstasyonu Fiyat Analizi")
                .font(.headline)

            Text("DC ortalama fiyat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if operatorAverages.isEmpty {
                EmptyInfoCard(
                    title: "Operatör analizi için veri yok",
                    subtitle: "Enerji bilgisi olan DC şarj kayıtları ekledikçe burada görünür.",
                    iconName: "bolt.circle"
                )
            } else {
                ForEach(Array(operatorAverages.enumerated()), id: \.element.id) { index, item in
                    row(item: item, isCheapest: index == 0)
                    if index < operatorAverages.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(item: OperatorPriceAverage, isCheapest: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.operatorName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isCheapest {
                        Text("En ucuz")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.homeColor.opacity(0.18))
                            .foregroundStyle(AppTheme.homeColor)
                            .clipShape(Capsule())
                    }
                }

                Text("\(item.sessionCount) seans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(NumberFormatting.currency(item.averageTLPerKWh, code: currencyCode)) / kWh")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isCheapest ? AppTheme.homeColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
struct StationPriceAnalysisCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            StationPriceAnalysisCard(
                operatorAverages: [
                    OperatorPriceAverage(operatorName: "ZES", averageTLPerKWh: 10.8, sessionCount: 4),
                    OperatorPriceAverage(operatorName: "Lumicle", averageTLPerKWh: 11.3, sessionCount: 3),
                    OperatorPriceAverage(operatorName: "Eşarj", averageTLPerKWh: 11.6, sessionCount: 5)
                ],
                currencyCode: "TRY"
            )

            StationPriceAnalysisCard(operatorAverages: [], currencyCode: "TRY")
        }
        .padding()
    }
}
#endif
