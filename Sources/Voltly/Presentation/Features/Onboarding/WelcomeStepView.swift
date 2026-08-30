import SwiftUI

/// Şarj takibinin temel yapı taşlarını anlatan hoş geldin adımı.
public struct WelcomeStepView: View {
    private let page: OnboardingPageModel

    @State private var animateIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(page: OnboardingPageModel) {
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xLarge) {
            Text(page.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(revealAnimation(delay: 0.02), value: animateIn)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(Color.secondary.opacity(0.95))
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(revealAnimation(delay: 0.08), value: animateIn)

            AnimatedBatteryCard()
                .scaleEffect(animateIn ? 1 : OnboardingTokens.reducedScale(0.98, reduceMotion: reduceMotion))
                .opacity(animateIn ? 1 : 0)
                .animation(revealAnimation(delay: 0.14), value: animateIn)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: OnboardingTokens.Spacing.small)], spacing: OnboardingTokens.Spacing.small) {
                ForEach(Array(page.chips.enumerated()), id: \.offset) { index, chip in
                    MetricChip(title: chip)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.tinyOffset, reduceMotion: reduceMotion))
                        .animation(revealAnimation(delay: 0.18 + (Double(index) * 0.04)), value: animateIn)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            animateIn = true
        }
    }

    private func revealAnimation(delay: Double) -> Animation {
        OnboardingTokens.revealAnimation(reduceMotion: reduceMotion, delay: delay)
    }
}

#if DEBUG
struct WelcomeStepView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeStepView(page: .defaultPages[1])
            .padding(20)
    }
}
#endif
