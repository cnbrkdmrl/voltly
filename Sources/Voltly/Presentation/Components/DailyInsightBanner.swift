import SwiftUI

public struct DailyInsightBanner: View {
    private let text: String
    private let isPlaceholder: Bool

    public init(
        text: String,
        isPlaceholder: Bool = false
    ) {
        self.text = text
        self.isPlaceholder = isPlaceholder
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isPlaceholder ? "sparkles" : "bolt.badge.clock")
                .foregroundStyle(isPlaceholder ? .secondary : AppTheme.publicACColor)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Günlük içgörü: \(text)")
    }
}
