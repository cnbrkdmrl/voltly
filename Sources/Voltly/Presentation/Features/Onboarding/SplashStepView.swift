import SwiftUI

/// Onboarding'in ilk adımındaki logo ve kısa değer önerisini gösterir.
public struct SplashStepView: View {
    private let page: OnboardingPageModel

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(page: OnboardingPageModel) {
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xLarge) {
            Spacer(minLength: OnboardingTokens.Spacing.medium)

            ZStack {
                Circle()
                    .fill(OnboardingStyle.accent.opacity(0.18))
                    .frame(width: OnboardingTokens.Size.splashHalo, height: OnboardingTokens.Size.splashHalo)
                    .opacity(isVisible ? 1 : 0)

                BrandLogoView(
                    size: OnboardingTokens.Size.splashLogo,
                    cornerRadius: OnboardingTokens.CornerRadius.xLarge
                )
                    .scaleEffect(isVisible ? 1 : OnboardingTokens.reducedScale(0.96, reduceMotion: reduceMotion))
                    .opacity(isVisible ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(page.title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.tinyOffset, reduceMotion: reduceMotion))

            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(Color.secondary.opacity(0.95))
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.smallOffset, reduceMotion: reduceMotion))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .onAppear(perform: runEntryAnimation)
    }

    private func runEntryAnimation() {
        withAnimation(entryAnimation) {
            isVisible = true
        }
    }

    private var entryAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .easeOut(duration: OnboardingTokens.Motion.splashDuration)
    }
}

#if DEBUG
struct SplashStepView_Previews: PreviewProvider {
    static var previews: some View {
        SplashStepView(page: .defaultPages[0])
            .padding(20)
            .background(OnboardingStyle.background(for: .light))
    }
}
#endif
