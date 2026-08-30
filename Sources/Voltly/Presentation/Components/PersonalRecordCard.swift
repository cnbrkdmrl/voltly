import SwiftUI

public struct PersonalRecordCard: View {
    private let item: PersonalRecordItem
    private let onTap: () -> Void

    public init(
        item: PersonalRecordItem,
        onTap: @escaping () -> Void
    ) {
        self.item = item
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.16))
                    Image(systemName: item.type.iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(item.type.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        confidenceBadge
                    }

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let note = item.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(item.metricText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accentColor)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [AppTheme.surface, AppTheme.overlaySurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var confidenceBadge: some View {
        Text(confidenceTitle)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(confidenceColor.opacity(0.15))
            .foregroundStyle(confidenceColor)
            .clipShape(Capsule())
    }

    private var accentColor: Color {
        switch item.type {
        case .cheapestCharge, .mostEfficientCharge, .shortestSession:
            return AppTheme.homeColor
        case .mostExpensiveCharge, .longestSession:
            return AppTheme.publicDCColor
        case .highestEnergySession:
            return AppTheme.publicACColor
        }
    }

    private var confidenceColor: Color {
        switch item.confidence.source {
        case .real:
            return AppTheme.homeColor
        case .mixed:
            return AppTheme.publicACColor
        case .estimated:
            return .orange
        case .unavailable:
            return .secondary
        }
    }

    private var confidenceTitle: String {
        switch item.confidence.source {
        case .real:
            return "Gercek"
        case .mixed:
            return "Karma"
        case .estimated:
            return "Tahmini"
        case .unavailable:
            return "Yok"
        }
    }
}

