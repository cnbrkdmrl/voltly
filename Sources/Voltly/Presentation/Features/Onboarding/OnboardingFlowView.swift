import SwiftUI

/// Onboarding akışının tüm adımlarını ve geçişlerini yöneten ana ekran.
public struct OnboardingFlowView: View {
    private enum NavigationDirection {
        case forward
        case backward
    }

    private enum Layout {
        static let horizontalPadding = OnboardingTokens.Spacing.xxLarge
        static let verticalSpacing = OnboardingTokens.Spacing.xLarge
        static let contentTopPadding = OnboardingTokens.Spacing.small
        static let actionBottomPadding = OnboardingTokens.Spacing.xxLarge
        static let actionCardPadding = OnboardingTokens.Spacing.medium
    }

    private let pages: [OnboardingPageModel]
    private let onComplete: (LaunchAccessMode) -> Void

    @State private var currentIndex = 0
    @State private var direction: NavigationDirection = .forward
    @State private var accountChoice: OnboardingAccountChoice?
    @State private var selectedComparisonType: ChargeComparisonType = .ac

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        pages: [OnboardingPageModel] = OnboardingPageModel.defaultPages,
        onComplete: @escaping (LaunchAccessMode) -> Void
    ) {
        self.pages = pages
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            OnboardingStyle.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: Layout.verticalSpacing) {
                OnboardingProgressView(
                    totalSteps: pages.count,
                    currentStep: currentIndex
                )
                .padding(.top, Layout.contentTopPadding)

                stepContainer

                Spacer(minLength: 0)

                actionArea
                    .padding(.bottom, Layout.actionBottomPadding)
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .onChange(of: isPrimaryButtonEnabled) { oldValue, newValue in
            guard isLastPage else { return }
            if oldValue == false && newValue == true {
                Haptics.softImpact()
            }
        }
    }

    private var stepContent: some View {
        ZStack {
            switch currentPage.type {
            case .splash:
                SplashStepView(page: currentPage)
            case .welcome:
                WelcomeStepView(page: currentPage)
            case .costAnalysis:
                CostAnalysisStepView(page: currentPage)
            case .comparison:
                ComparisonStepView(
                    page: currentPage,
                    selectedType: $selectedComparisonType
                )
            case .accountChoice:
                AccountChoiceStepView(
                    page: currentPage,
                    selectedChoice: $accountChoice
                )
            }
        }
        .id(currentPage.id)
        .frame(maxWidth: .infinity, alignment: .top)
        .transition(pageTransition)
        .animation(pageAnimation, value: currentIndex)
    }

    @ViewBuilder
    private var stepContainer: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.vertical, showsIndicators: false) {
                stepContent
                    .padding(.bottom, OnboardingTokens.Spacing.small)
            }
        } else {
            stepContent
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            PrimaryCTAButton(
                title: primaryButtonTitle,
                isEnabled: isPrimaryButtonEnabled,
                action: handlePrimaryAction
            )
            .animation(.easeInOut(duration: 0.20), value: isPrimaryButtonEnabled)

            SecondaryTextButton(
                title: "Geri",
                isHidden: currentIndex == 0,
                action: goBackward
            )
        }
        .padding(Layout.actionCardPadding)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.xLarge, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.04))
        )
    }

    private var currentPage: OnboardingPageModel {
        pages[currentIndex]
    }

    private var isLastPage: Bool {
        currentIndex == pages.count - 1
    }

    private var isPrimaryButtonEnabled: Bool {
        guard isLastPage else { return true }
        return accountChoice != nil
    }

    private var primaryButtonTitle: String {
        isLastPage ? "İlk Aracını Ekle" : "İleri"
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private var pageAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.42, dampingFraction: 0.92, blendDuration: 0.1)
    }

    private func handlePrimaryAction() {
        if isLastPage {
            guard let choice = accountChoice else { return }
            Haptics.success()
            onComplete(choice.launchAccessMode)
            return
        }
        goForward()
    }

    private func goForward() {
        guard currentIndex < pages.count - 1 else { return }
        direction = .forward
        withAnimation(pageAnimation) {
            currentIndex += 1
        }
        Haptics.selection()
    }

    private func goBackward() {
        guard currentIndex > 0 else { return }
        direction = .backward
        withAnimation(pageAnimation) {
            currentIndex -= 1
        }
        Haptics.selection()
    }
}

#if DEBUG
struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingFlowView { _ in }
            OnboardingFlowView { _ in }
                .preferredColorScheme(.dark)
        }
    }
}
#endif
