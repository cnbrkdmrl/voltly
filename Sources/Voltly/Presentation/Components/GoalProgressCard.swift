import SwiftUI

public struct GoalProgressCard: View {
    private let item: GoalProgressItem

    public init(item: GoalProgressItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.iconName)
                    .foregroundStyle(toneColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Text(item.headline)
                        .font(.headline)
                }
                Spacer()
            }

            ProgressView(value: item.progressFraction)
                .tint(toneColor)

            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text("Mevcut: \(item.currentValueText)")
                Spacer()
                Text("Hedef: \(item.targetValueText)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var toneColor: Color {
        switch item.tone {
        case .success:
            return .green
        case .neutral:
            return AppTheme.publicACColor
        case .warning:
            return .orange
        }
    }
}
