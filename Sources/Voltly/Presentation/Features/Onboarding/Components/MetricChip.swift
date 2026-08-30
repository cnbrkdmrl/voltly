import SwiftUI

/// Küçük metrik etiketlerini tek tip bir görünümde sunar.
public struct MetricChip: View {
    private let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.primary.opacity(0.82))
            .padding(.horizontal, OnboardingTokens.Spacing.medium + 2)
            .padding(.vertical, OnboardingTokens.Spacing.small)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .accessibilityLabel("Metrik: \(title)")
    }
}

#if DEBUG
struct MetricChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            MetricChip(title: "kWh")
            MetricChip(title: "TL")
            MetricChip(title: "SOC")
            MetricChip(title: "AC/DC")
        }
        .padding()
    }
}
#endif
