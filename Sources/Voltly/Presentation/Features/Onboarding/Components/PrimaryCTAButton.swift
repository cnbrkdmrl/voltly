import SwiftUI

/// Onboarding boyunca kullanılan geniş birincil aksiyon butonu.
public struct PrimaryCTAButton: View {
    private let title: String
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .controlSize(.small)
                }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .frame(minHeight: OnboardingTokens.Size.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.large, style: .continuous)
                    .fill(isEnabled ? OnboardingStyle.accent : OnboardingStyle.accent.opacity(0.42))
            )
            .shadow(color: OnboardingStyle.accent.opacity(isEnabled ? 0.22 : 0), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.20), value: isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "Devam etmek için çift dokun." : "Bu işlem için önce bir seçim yapman gerekiyor.")
    }
}

#if DEBUG
struct PrimaryCTAButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            PrimaryCTAButton(title: "İleri", action: {})
            PrimaryCTAButton(title: "İlk Aracını Ekle", isEnabled: false, action: {})
            PrimaryCTAButton(title: "Kaydediliyor", isLoading: true, action: {})
        }
        .padding()
    }
}
#endif
