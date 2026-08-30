import SwiftUI

/// Son adımda hesap seçimi için kullanılan tekrar kullanılabilir seçim kartı.
public struct SelectableOptionCard: View {
    private let title: String
    private let subtitle: String
    private let details: [String]
    private let isSelected: Bool
    private let isRecommended: Bool
    private let detailIconName: String
    private let detailIconTint: Color
    private let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String,
        details: [String],
        isSelected: Bool,
        isRecommended: Bool = false,
        detailIconName: String = "checkmark.circle.fill",
        detailIconTint: Color = OnboardingStyle.accentDark,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.isSelected = isSelected
        self.isRecommended = isRecommended
        self.detailIconName = detailIconName
        self.detailIconTint = detailIconTint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.medium) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xSmall) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 10)
                    if isRecommended {
                        RecommendedBadge()
                    }
                }

                VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xSmall) {
                    ForEach(details, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: OnboardingTokens.Spacing.xSmall) {
                            Image(systemName: detailIconName)
                                .font(.caption)
                                .foregroundStyle(isSelected ? detailIconTint : Color.secondary.opacity(0.65))
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(isSelected ? 0.88 : 0.64))
                        }
                    }
                }
                .opacity(isSelected ? 1 : 0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OnboardingTokens.Spacing.xLarge)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.xLarge, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.xLarge, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1.2)
            )
            .scaleEffect(isSelected ? OnboardingTokens.reducedScale(1.01, reduceMotion: reduceMotion) : 1)
            .shadow(color: OnboardingStyle.accent.opacity(isSelected ? 0.14 : 0), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.36, dampingFraction: 0.9),
            value: isSelected
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
        .accessibilityHint(subtitle)
    }

    private var backgroundFill: some ShapeStyle {
        if isRecommended {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        OnboardingStyle.accentSoft.opacity(isSelected ? 0.36 : 0.24),
                        Color.primary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.primary.opacity(0.06))
    }

    private var borderColor: Color {
        if isSelected { return OnboardingStyle.accent }
        if isRecommended { return OnboardingStyle.accent.opacity(0.45) }
        return Color.primary.opacity(0.09)
    }
}

#if DEBUG
struct SelectableOptionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            SelectableOptionCard(
                title: "Hesap oluştur",
                subtitle: "Verilerini güvenle yedekle.",
                details: ["Bulut yedekleme", "Birden fazla araç desteği"],
                isSelected: true,
                isRecommended: true,
                action: {}
            )
            SelectableOptionCard(
                title: "Misafir olarak devam et",
                subtitle: "Hızlıca başla.",
                details: ["Veriler sadece bu cihazda saklanır", "Bulut yedekleme yok"],
                isSelected: false,
                detailIconName: "minus.circle.fill",
                detailIconTint: AppTheme.publicDCColor,
                action: {}
            )
        }
        .padding()
    }
}
#endif
