import WidgetKit
import SwiftUI

@main
struct VoltlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        VoltlyHomeWidget()
    }
}

struct VoltlyHomeWidget: Widget {
    private let kind = "VoltlyHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoltlyWidgetProvider()) { entry in
            VoltlyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Voltly")
        .description("Bu ayki EV maliyeti ve temel şarj metrikleri.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
