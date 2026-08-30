import SwiftUI

#if os(iOS)
import UIKit

public enum MonthlySummaryExportAspectRatio: String, CaseIterable {
    case story
    case portrait
    case square

    public var titleTR: String {
        switch self {
        case .story:
            return "Story"
        case .portrait:
            return "Portre"
        case .square:
            return "Kare"
        }
    }

    fileprivate var canvasSize: CGSize {
        switch self {
        case .story:
            return CGSize(width: 1080, height: 1920) // 9:16
        case .portrait:
            return CGSize(width: 1080, height: 1350) // 4:5
        case .square:
            return CGSize(width: 1080, height: 1080) // 1:1
        }
    }
}

public struct MonthlySummaryRenderConfiguration {
    public let aspectRatio: MonthlySummaryExportAspectRatio
    public let colorScheme: ColorScheme
    public let scale: CGFloat

    public init(
        aspectRatio: MonthlySummaryExportAspectRatio = .story,
        colorScheme: ColorScheme = .dark,
        scale: CGFloat = UIScreen.main.scale
    ) {
        self.aspectRatio = aspectRatio
        self.colorScheme = colorScheme
        self.scale = scale
    }
}

@MainActor
public struct MonthlySummaryShareRenderer {
    public init() {}

    public func render(
        summary: MonthlyEVReportSummary,
        configuration: MonthlySummaryRenderConfiguration = .init()
    ) -> UIImage? {
        let canvas = configuration.aspectRatio.canvasSize
        let cardWidth = max(320, canvas.width * 0.88)
        let cardHeight = max(420, canvas.height * 0.88)

        let content = ZStack {
            AppTheme.heroBackground
            MonthlySummaryView(summary: summary, style: .shareCard)
                .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, configuration.colorScheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = configuration.scale
        return renderer.uiImage
    }
}
#endif
