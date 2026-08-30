import SwiftUI

/// AC ve DC şarj davranışını karşılaştırmalı anlatan onboarding adımı.
public struct ComparisonStepView: View {
    private let page: OnboardingPageModel
    @Binding private var selectedType: ChargeComparisonType

    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(page: OnboardingPageModel, selectedType: Binding<ChargeComparisonType>) {
        self.page = page
        self._selectedType = selectedType
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xLarge) {
            Text(page.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(entryAnimation(delay: 0.02), value: reveal)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(Color.secondary.opacity(0.95))
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(entryAnimation(delay: 0.08), value: reveal)

            ChargeTypeComparisonCard(
                type: .ac,
                title: "Maliyet odaklı günlük kullanım",
                subtitle: "Genelde daha düşük TL/kWh ile planlı şarj.",
                tint: AppTheme.publicACColor,
                isSelected: selectedType == .ac,
                action: { select(.ac) }
            )
            .opacity(reveal ? 1 : 0)
            .offset(
                x: reveal ? 0 : OnboardingTokens.reducedOffset(-OnboardingTokens.Motion.largeOffset, reduceMotion: reduceMotion),
                y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.smallOffset, reduceMotion: reduceMotion)
            )
            .animation(entryAnimation(delay: 0.14), value: reveal)

            ChargeTypeComparisonCard(
                type: .dc,
                title: "Hız odaklı yolculuk şarjı",
                subtitle: "Kısa molada daha hızlı dolum, farklı maliyet profili.",
                tint: AppTheme.publicDCColor,
                isSelected: selectedType == .dc,
                action: { select(.dc) }
            )
            .opacity(reveal ? 1 : 0)
            .offset(
                x: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.largeOffset, reduceMotion: reduceMotion),
                y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.smallOffset, reduceMotion: reduceMotion)
            )
            .animation(entryAnimation(delay: 0.20), value: reveal)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            reveal = true
        }
    }

    private func select(_ type: ChargeComparisonType) {
        let animation: Animation = reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.30, dampingFraction: 0.9)
        withAnimation(animation) {
            selectedType = type
        }
        Haptics.selection()
    }

    private func entryAnimation(delay: Double) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.18).delay(delay * 0.2)
        }
        return .easeOut(duration: OnboardingTokens.Motion.cardDuration).delay(delay)
    }
}

#if DEBUG
struct ComparisonStepView_Previews: PreviewProvider {
    static var previews: some View {
        ComparisonStepPreviewHost()
            .padding(20)
    }
}

private struct ComparisonStepPreviewHost: View {
    @State private var selected: ChargeComparisonType = .ac

    var body: some View {
        ComparisonStepView(page: .defaultPages[3], selectedType: $selected)
    }
}
#endif
