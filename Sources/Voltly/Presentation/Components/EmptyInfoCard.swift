import SwiftUI

public struct EmptyInfoCard: View {
    private let title: String
    private let subtitle: String
    private let iconName: String

    public init(
        title: String,
        subtitle: String,
        iconName: String = "info.circle"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(AppTheme.publicACColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct EmptyInfoCard_Previews: PreviewProvider {
    static var previews: some View {
        EmptyInfoCard(
            title: "Henüz yeterli veri yok",
            subtitle: "En az 2 kayıt gerekli"
        )
        .padding()
    }
}
#endif
