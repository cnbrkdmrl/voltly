import SwiftUI

public struct RetentionPromptBanner: View {
    private let prompt: InAppReminderMessage

    public init(prompt: InAppReminderMessage) {
        self.prompt = prompt
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName(for: prompt.type))
                .foregroundStyle(AppTheme.publicDCColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(prompt.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func iconName(for type: RetentionPromptType) -> String {
        switch type {
        case .missingRecentEntry:
            return "clock.badge.exclamationmark"
        case .monthlySummaryNeedsData:
            return "calendar.badge.plus"
        case .goalFollowUpNeeded:
            return "target"
        }
    }
}

