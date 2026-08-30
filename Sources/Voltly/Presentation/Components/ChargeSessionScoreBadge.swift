import SwiftUI

public struct ChargeSessionScoreBadge: View {
    private let report: ChargeSessionScoreReport

    public init(report: ChargeSessionScoreReport) {
        self.report = report
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(NumberFormatting.oneDecimal(report.overallScore))
                .font(.caption.weight(.bold))
            Text(ChargeSessionScoringText.sessionBadgeTitle(for: report.label))
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(backgroundColor.opacity(0.16))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch report.label {
        case .veryGood:
            return AppTheme.homeColor
        case .good:
            return AppTheme.publicACColor
        case .average:
            return .orange
        case .expensive, .inefficient:
            return .red
        }
    }
}

public struct ChargeSessionScoreSummaryView: View {
    private let report: ChargeSessionScoreReport
    private let showComment: Bool

    public init(
        report: ChargeSessionScoreReport,
        showComment: Bool = true
    ) {
        self.report = report
        self.showComment = showComment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ChargeSessionScoreBadge(report: report)
                Text(ChargeSessionScoringText.scoreSummary(score: report.overallScore, label: report.label))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if showComment {
                Text(report.primaryComment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
