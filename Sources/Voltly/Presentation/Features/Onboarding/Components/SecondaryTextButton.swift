import SwiftUI

/// Birincil aksiyonu destekleyen sade metin butonu.
public struct SecondaryTextButton: View {
    private let title: String
    private let isHidden: Bool
    private let action: () -> Void

    public init(
        title: String,
        isHidden: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isHidden = isHidden
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHidden ? 0 : 1)
        .allowsHitTesting(!isHidden)
        .accessibilityHidden(isHidden)
        .animation(.easeInOut(duration: 0.20), value: isHidden)
    }
}

#if DEBUG
struct SecondaryTextButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            SecondaryTextButton(title: "Geri", action: {})
            SecondaryTextButton(title: "Geri", isHidden: true, action: {})
        }
        .padding()
    }
}
#endif
