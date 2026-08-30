import SwiftUI

/// Enerji takibi fikrini sade bir batarya görseliyle anlatan kart.
public struct AnimatedBatteryCard: View {
    private let title: String
    private let subtitle: String
    private let targetLevel: Double

    @State private var animatedLevel: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String = "Şarj durumunu tek ekranda takip et",
        subtitle: String = "SOC, enerji ve maliyet birlikte görünür.",
        targetLevel: Double = 0.78
    ) {
        self.title = title
        self.subtitle = subtitle
        self.targetLevel = min(max(0, targetLevel), 1)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.medium) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.secondary.opacity(0.95))

            HStack(spacing: OnboardingTokens.Spacing.medium) {
                batteryBody
                VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xxSmall) {
                    Text("Seans Örneği")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                    Text("%20 → %80")
                        .font(.subheadline.weight(.semibold))
                    Text("+%60")
                        .font(.caption)
                        .foregroundStyle(OnboardingStyle.accentDark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(OnboardingTokens.Spacing.xLarge)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.xLarge, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .onAppear {
            withAnimation(fillAnimation) {
                animatedLevel = targetLevel
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Batarya özet kartı")
        .accessibilityValue("Şarj yüzdesi yüzde 20'den 80'e, artış yüzde 60.")
    }

    private var batteryBody: some View {
        HStack(spacing: OnboardingTokens.Spacing.xxSmall) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.small, style: .continuous)
                    .stroke(Color.primary.opacity(0.22), lineWidth: 1.5)
                    .frame(width: OnboardingTokens.Size.batteryWidth, height: OnboardingTokens.Size.batteryHeight)

                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.tiny, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [OnboardingStyle.accent, OnboardingStyle.accentSoft],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, 92 * animatedLevel), height: 30)
                    .padding(.leading, 2)
            }
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.primary.opacity(0.28))
                .frame(width: 4, height: 14)
        }
    }

    private var fillAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.50, dampingFraction: 0.9, blendDuration: 0.1)
    }
}

#if DEBUG
struct AnimatedBatteryCard_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedBatteryCard()
            .padding()
    }
}
#endif
