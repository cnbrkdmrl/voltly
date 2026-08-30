import SwiftUI

public struct SmartChargeSuggestionCard: View {
    private let suggestion: SmartChargeSuggestion

    public init(suggestion: SmartChargeSuggestion) {
        self.suggestion = suggestion
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Akıllı Şarj Önerisi")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.badge.clock.fill")
                    .foregroundStyle(AppTheme.publicACColor)
                    .font(.headline)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                    Text(suggestion.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                statItem(
                    title: "AC ortalama",
                    value: "\(NumberFormatting.currency(suggestion.acAverageTLPerKWh, code: suggestion.currencyCode)) / kWh"
                )

                statItem(
                    title: "DC ortalama",
                    value: "\(NumberFormatting.currency(suggestion.dcAverageTLPerKWh, code: suggestion.currencyCode)) / kWh"
                )
            }

            Text("Karşılaştırılan DC enerji: \(NumberFormatting.oneDecimal(suggestion.comparedEnergyKWh)) kWh")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
struct SmartChargeSuggestionCard_Previews: PreviewProvider {
    static var previews: some View {
        SmartChargeSuggestionCard(
            suggestion: SmartChargeSuggestion(
                title: "Bu ay için maliyet fırsatı",
                message: "Bu ay DC yerine AC kullansaydın ₺820 daha az ödeyebilirdin.",
                potentialSavings: 820,
                comparedEnergyKWh: 120.4,
                acAverageTLPerKWh: 10.8,
                dcAverageTLPerKWh: 11.6,
                currencyCode: "TRY"
            )
        )
        .padding()
    }
}
#endif
