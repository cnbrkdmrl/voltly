import SwiftUI

public struct FloatingStatusBanner: View {
    private let title: String
    private let systemImage: String
    private let tint: Color

    public init(
        title: String,
        systemImage: String = "checkmark.circle.fill",
        tint: Color = AppTheme.publicACColor
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.96))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 3)
    }
}
