import SwiftUI

/// Onboarding'in son adımında hesap seçimi yapılmasını sağlayan ekran.
public struct AccountChoiceStepView: View {
    private let page: OnboardingPageModel
    @Binding private var selectedChoice: OnboardingAccountChoice?

    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(page: OnboardingPageModel, selectedChoice: Binding<OnboardingAccountChoice?>) {
        self.page = page
        self._selectedChoice = selectedChoice
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.large) {
            Text(page.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(entryAnimation(delay: 0.02), value: reveal)

            SelectableOptionCard(
                title: "Hesap oluştur",
                subtitle: "Verilerini güvenle yedekle ve tüm Voltly özelliklerine eriş.",
                details: [
                    "Bulut yedekleme",
                    "Birden fazla araç desteği",
                    "Gelişmiş analizler",
                    "Yeni özelliklere erken erişim"
                ],
                isSelected: selectedChoice == .createAccount,
                isRecommended: true,
                action: { select(.createAccount) }
            )
            .opacity(reveal ? 1 : 0)
            .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.largeOffset, reduceMotion: reduceMotion))
            .animation(entryAnimation(delay: 0.10), value: reveal)

            SelectableOptionCard(
                title: "Misafir olarak devam et",
                subtitle: "Hızlıca başla, verilerin bu cihazda kalsın.",
                details: [
                    "Limit: Veriler sadece bu cihazda saklanır",
                    "Limit: Bulut yedekleme yok",
                    "Limit: Analiz kapsamı daha sınırlıdır",
                    "Limit: Tek cihaz deneyimi"
                ],
                isSelected: selectedChoice == .guest,
                detailIconName: "minus.circle.fill",
                detailIconTint: AppTheme.publicDCColor,
                action: { select(.guest) }
            )
            .opacity(reveal ? 1 : 0)
            .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.largeOffset, reduceMotion: reduceMotion))
            .animation(entryAnimation(delay: 0.16), value: reveal)

            Text("Devam etmek için bir seçenek belirle.")
                .font(.footnote)
                .foregroundStyle(Color.secondary.opacity(0.95))
                .opacity(reveal ? 1 : 0)
                .animation(entryAnimation(delay: 0.22), value: reveal)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            reveal = true
        }
    }

    private func select(_ choice: OnboardingAccountChoice) {
        let animation: Animation = reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.32, dampingFraction: 0.9)
        withAnimation(animation) {
            selectedChoice = choice
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
struct AccountChoiceStepView_Previews: PreviewProvider {
    static var previews: some View {
        AccountChoicePreviewHost()
            .padding(20)
    }
}

private struct AccountChoicePreviewHost: View {
    @State private var choice: OnboardingAccountChoice? = .createAccount

    var body: some View {
        AccountChoiceStepView(page: .defaultPages[4], selectedChoice: $choice)
    }
}
#endif
