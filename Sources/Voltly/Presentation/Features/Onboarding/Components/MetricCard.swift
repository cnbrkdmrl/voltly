import SwiftUI

/// Onboarding içinde örnek hesap metriklerini gösteren kart bileşeni.
public struct MetricCard: View {
    private let value: String
    private let subtitle: String

    public init(value: String, subtitle: String) {
        self.value = value
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xSmall) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OnboardingTokens.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.large, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subtitle): \(value)")
    }
}

#if DEBUG
struct MetricCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 10) {
            MetricCard(value: "5.42", subtitle: "TL/kWh")
            MetricCard(value: "17.8", subtitle: "TL / 100 km")
        }
        .padding()
    }
}
#endif
