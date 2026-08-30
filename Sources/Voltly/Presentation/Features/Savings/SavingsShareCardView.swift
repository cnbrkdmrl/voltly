import SwiftUI

public enum SavingsShareCardVariant: String, CaseIterable, Identifiable, Sendable {
    case monthlySavings
    case planSuccess
    case goalCompletion
    case dcReduction
    case carbonGain

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .monthlySavings:
            return "Bu Ay Tasarruf"
        case .planSuccess:
            return "Plan Başarısı"
        case .goalCompletion:
            return "Hedef İlerlemesi"
        case .dcReduction:
            return "DC Azaltma Etkisi"
        case .carbonGain:
            return "Karbon Kazanımı"
        }
    }
}

public struct SavingsShareCardMetric: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let value: String

    public init(id: String, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}

public struct SavingsShareCardContent: Equatable, Sendable {
    public let variant: SavingsShareCardVariant
    public let badgeTitle: String
    public let headline: String
    public let supportingText: String
    public let vehicleName: String
    public let metrics: [SavingsShareCardMetric]
    public let highlightText: String
    public let footerText: String

    public init(
        variant: SavingsShareCardVariant,
        badgeTitle: String,
        headline: String,
        supportingText: String,
        vehicleName: String,
        metrics: [SavingsShareCardMetric],
        highlightText: String,
        footerText: String
    ) {
        self.variant = variant
        self.badgeTitle = badgeTitle
        self.headline = headline
        self.supportingText = supportingText
        self.vehicleName = vehicleName
        self.metrics = metrics
        self.highlightText = highlightText
        self.footerText = footerText
    }
}

public struct SavingsShareCardView: View {
    let content: SavingsShareCardContent

    public init(content: SavingsShareCardContent) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Voltly")
                        .font(.title3.weight(.black))
                    Spacer()
                    BrandLogoView(size: 34, cornerRadius: 10)
                }
                .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    Text(content.badgeTitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(content.headline)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(content.supportingText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(content.vehicleName)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.95))

                    ForEach(Array(metricRows.enumerated()), id: \.offset) { element in
                        HStack(spacing: 8) {
                            ForEach(element.element) { metric in
                                statPill(metric.title, metric.value)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                Text(content.highlightText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 10) {
                    BrandLogoView(size: 22, cornerRadius: 6)
                    Text(content.footerText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var metricRows: [[SavingsShareCardMetric]] {
        stride(from: 0, to: min(content.metrics.count, 4), by: 2).map { index in
            Array(content.metrics[index..<min(index + 2, content.metrics.count)])
        }
    }

    private var gradientColors: [Color] {
        switch content.variant {
        case .monthlySavings:
            return [
                AppTheme.heroBackground,
                AppTheme.publicACColor.opacity(0.85),
                AppTheme.dcAccent.opacity(0.8)
            ]
        case .planSuccess:
            return [
                AppTheme.heroBackground,
                AppTheme.homeColor.opacity(0.88),
                AppTheme.publicACColor.opacity(0.82)
            ]
        case .goalCompletion:
            return [
                AppTheme.heroBackground,
                AppTheme.publicACColor.opacity(0.88),
                Color.indigo.opacity(0.82)
            ]
        case .dcReduction:
            return [
                AppTheme.heroBackground,
                AppTheme.publicDCColor.opacity(0.84),
                AppTheme.homeColor.opacity(0.8)
            ]
        case .carbonGain:
            return [
                AppTheme.heroBackground,
                Color.green.opacity(0.8),
                AppTheme.homeColor.opacity(0.85)
            ]
        }
    }

    private func statPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
