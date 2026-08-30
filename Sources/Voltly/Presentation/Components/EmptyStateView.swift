import SwiftUI

public struct EmptyStateView: View {
    private let title: String
    private let subtitle: String
    private let iconName: String
    private let actionTitle: String?
    private let onAction: (() -> Void)?

    public init(
        title: String,
        subtitle: String,
        iconName: String = "tray",
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.publicACColor)
                .frame(width: 44, height: 44)
                .background(AppTheme.publicACColor.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.publicDCColor)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                title: "Henüz şarj kaydı yok",
                subtitle: "İlk şarjını ekleyerek EV maliyetini hesaplamaya başla.",
                iconName: "bolt.fill",
                actionTitle: "İlk şarjı ekle"
            )

            EmptyStateView(
                title: "Henüz analiz verisi yok",
                subtitle: "İlk birkaç şarjdan sonra maliyet analizleri burada görünür.",
                iconName: "chart.line.uptrend.xyaxis"
            )
        }
        .padding()
    }
}
#endif
