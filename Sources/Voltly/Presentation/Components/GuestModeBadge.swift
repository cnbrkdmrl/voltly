import SwiftUI

public enum GuestModeBadgeStyle {
    case compact
    case detailed
}

public struct GuestModeBadge: View {
    private let subtitle: String?
    private let style: GuestModeBadgeStyle

    public init(
        subtitle: String? = nil,
        style: GuestModeBadgeStyle = .compact
    ) {
        self.subtitle = subtitle
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.publicACColor)
                .frame(width: 20, height: 20)
                .background(AppTheme.publicACColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Misafir mod")
                    .font(.footnote.weight(.semibold))
                if style == .detailed, let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, style == .compact ? 10 : 12)
        .padding(.vertical, style == .compact ? 7 : 9)
        .background(AppTheme.publicACColor.opacity(style == .compact ? 0.08 : 0.10))
        .overlay(
            RoundedRectangle(cornerRadius: style == .compact ? 10 : 12)
                .stroke(AppTheme.publicACColor.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: style == .compact ? 10 : 12))
    }
}

#if DEBUG
struct GuestModeBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            GuestModeBadge(style: .compact)
                .padding()
            GuestModeBadge(
                subtitle: "Veriler bu cihazda tutuluyor",
                style: .detailed
            )
            .padding()
        }
        .background(AppTheme.surface)
    }
}
#endif
