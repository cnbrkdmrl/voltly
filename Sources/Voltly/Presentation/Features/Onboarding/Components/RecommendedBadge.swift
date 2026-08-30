import SwiftUI

/// Önerilen seçeneği vurgulamak için kullanılan küçük etiket.
public struct RecommendedBadge: View {
    public init() {}

    public var body: some View {
        Text("Önerilen")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(OnboardingStyle.accentSoft)
            )
            .accessibilityLabel("Önerilen seçenek")
    }
}

#if DEBUG
struct RecommendedBadge_Previews: PreviewProvider {
    static var previews: some View {
        RecommendedBadge()
            .padding()
    }
}
#endif
