import SwiftUI

/// Onboarding adımları için özel ve sade bir ilerleme göstergesi.
public struct OnboardingProgressView: View {
    private let totalSteps: Int
    private let currentStep: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(totalSteps: Int, currentStep: Int) {
        self.totalSteps = max(1, totalSteps)
        self.currentStep = min(max(0, currentStep), max(0, totalSteps - 1))
    }

    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == currentStep ? OnboardingStyle.accent : Color.secondary.opacity(0.18))
                        .frame(
                            width: index == currentStep ? OnboardingTokens.Size.progressActiveWidth : OnboardingTokens.Size.progressInactiveWidth,
                            height: OnboardingTokens.Size.progressHeight
                        )
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: OnboardingTokens.Motion.quickDuration),
                            value: currentStep
                        )
                }
            }
            Spacer(minLength: 12)
            Text("Adım \(currentStep + 1)/\(totalSteps)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding ilerlemesi")
        .accessibilityValue("\(currentStep + 1) / \(totalSteps)")
    }
}

#if DEBUG
struct OnboardingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 14) {
            OnboardingProgressView(totalSteps: 5, currentStep: 0)
            OnboardingProgressView(totalSteps: 5, currentStep: 2)
            OnboardingProgressView(totalSteps: 5, currentStep: 4)
        }
        .padding()
    }
}
#endif
