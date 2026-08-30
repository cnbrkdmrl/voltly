import SwiftUI

/// AC ve DC seçeneklerini görsel olarak karşılaştıran seçilebilir kart.
public struct ChargeTypeComparisonCard: View {
    private let type: ChargeComparisonType
    private let title: String
    private let subtitle: String
    private let tint: Color
    private let isSelected: Bool
    private let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        type: ChargeComparisonType,
        title: String,
        subtitle: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.small) {
                HStack {
                    Text(type.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, OnboardingTokens.Spacing.small)
                        .padding(.vertical, OnboardingTokens.Spacing.xxSmall)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tint.opacity(0.18))
                        )
                    Spacer(minLength: 8)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OnboardingTokens.Spacing.xLarge)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.large, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.large, style: .continuous)
                    .stroke(isSelected ? tint : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? OnboardingTokens.reducedScale(1.01, reduceMotion: reduceMotion) : 1)
            .shadow(color: tint.opacity(isSelected ? 0.16 : 0), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.35, dampingFraction: 0.9),
            value: isSelected
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.rawValue) şarj seçeneği")
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
        .accessibilityHint(subtitle)
    }
}

#if DEBUG
struct ChargeTypeComparisonCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            ChargeTypeComparisonCard(
                type: .ac,
                title: "Daha düşük birim maliyet",
                subtitle: "Uzun duruşlarda genelde daha ekonomik.",
                tint: AppTheme.publicACColor,
                isSelected: true,
                action: {}
            )
            ChargeTypeComparisonCard(
                type: .dc,
                title: "Daha hızlı tamamlanan seans",
                subtitle: "Kısa molalarda zaman avantajı sağlar.",
                tint: AppTheme.publicDCColor,
                isSelected: false,
                action: {}
            )
        }
        .padding()
    }
}
#endif
