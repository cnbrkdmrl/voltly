import SwiftUI

public struct StatTile: View {
    private let title: String
    private let value: String
    private let footnote: String?

    public init(title: String, value: String, footnote: String? = nil) {
        self.title = title
        self.value = value
        self.footnote = footnote
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct StatTile_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            StatTile(title: "Aylık Tutar", value: "₺3.200")
            StatTile(title: "Seans", value: "12")
        }
        .padding()
    }
}
#endif
