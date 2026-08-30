import SwiftUI

public struct AnalysisConfidenceView: View {
    private let confidence: AnalysisConfidenceReport

    public init(confidence: AnalysisConfidenceReport) {
        self.confidence = confidence
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(confidence.level.titleTR)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(levelColor.opacity(0.16))
                    .foregroundStyle(levelColor)
                    .clipShape(Capsule())

                Text("%\(confidence.score)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(confidence.primaryText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let secondaryText = confidence.secondaryText {
                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.95))
            }
        }
    }

    private var levelColor: Color {
        switch confidence.level {
        case .high:
            return AppTheme.homeColor
        case .medium:
            return AppTheme.publicACColor
        case .low:
            return AppTheme.publicDCColor
        }
    }
}

#if DEBUG
struct AnalysisConfidenceView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            AnalysisConfidenceView(
                confidence: AnalysisConfidenceReport(
                    level: .high,
                    score: 84,
                    realDataPercent: 84,
                    source: .real,
                    primaryText: "Bu analiz %84 gerçek veriye dayanıyor.",
                    secondaryText: nil,
                    sampleCount: 18,
                    missingKMRatio: 0.11,
                    fallbackRatio: 0.06,
                    inconsistentRatio: 0.05
                )
            )

            AnalysisConfidenceView(
                confidence: AnalysisConfidenceReport(
                    level: .medium,
                    score: 67,
                    realDataPercent: 68,
                    source: .mixed,
                    primaryText: "Bu analiz %68 gerçek veriye dayanıyor.",
                    secondaryText: "Bazı kayıtlar tahmini hesaplandığı için sonuç yaklaşık görünebilir.",
                    sampleCount: 9,
                    missingKMRatio: 0.33,
                    fallbackRatio: 0.32,
                    inconsistentRatio: 0.12
                )
            )
        }
        .padding()
    }
}
#endif
