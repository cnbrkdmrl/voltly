import SwiftUI

public struct TotalSavingsCard: View {
    private let title: String
    private let amount: Double?
    private let savingsPercent: Double?
    private let currencyCode: String

    public init(
        title: String = "Toplam Tasarruf",
        amount: Double?,
        savingsPercent: Double?,
        currencyCode: String
    ) {
        self.title = title
        self.amount = amount
        self.savingsPercent = savingsPercent
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "banknote.fill")
                    .foregroundStyle(AppTheme.homeColor)
                Text(title)
                    .font(.headline)
            }

            if let amount {
                Text(NumberFormatting.currency(amount, code: currencyCode))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Text("Hesaplanamadı")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if let savingsPercent, let amount {
                let absPercent = abs(savingsPercent)
                if amount > 0 {
                    Text("Benzine gore \(NumberFormatting.percent(absPercent)) daha ucuz")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.homeColor)
                } else if amount < 0 {
                    Text("Benzine gore \(NumberFormatting.percent(absPercent)) daha pahali")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text("Benzin ile ayni maliyet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tasarruf karşılaştırması için yeterli veri yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct TotalSavingsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            TotalSavingsCard(
                amount: 18_420,
                savingsPercent: 52,
                currencyCode: "TRY"
            )

            TotalSavingsCard(
                amount: nil,
                savingsPercent: nil,
                currencyCode: "TRY"
            )
        }
        .padding()
    }
}
#endif
