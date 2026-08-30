import SwiftUI

public struct InsightCardRow: View {
    private let title: String
    private let detail: String
    private let iconName: String
    private let accent: Color

    public init(title: String, detail: String, iconName: String, accent: Color) {
        self.title = title
        self.detail = detail
        self.iconName = iconName
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(accent)
                .font(.headline)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
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
struct InsightCardRow_Previews: PreviewProvider {
    static var previews: some View {
        InsightCardRow(
            title: "Tasarruf önerisi",
            detail: "DC yerine Ev/AC ağırlıklı kullanım ile bu ay yaklaşık 420 TL daha az ödeyebilirdin.",
            iconName: "lightbulb.max.fill",
            accent: AppTheme.publicDCColor
        )
        .padding()
    }
}
#endif
