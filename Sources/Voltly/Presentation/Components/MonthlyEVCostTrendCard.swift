import Charts
import SwiftUI

public struct MonthlyEVCostTrendCard: View {
    private let points: [MonthlyEVCostPoint]
    private let currencyCode: String
    @State private var selectedPointID: Date?

    public init(points: [MonthlyEVCostPoint], currencyCode: String) {
        self.points = points
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aylık EV Maliyet Grafiği")
                .font(.headline)

            if hasData {
                chartContent
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        .onAppear {
            selectedPointID = selectedPoint?.id
        }
        .onChange(of: points.map(\.id)) { _, _ in
            selectedPointID = selectedPoint?.id
        }
    }

    private var hasData: Bool {
        points.contains { $0.sessionCount > 0 || $0.totalEnergyKWh > 0 || $0.totalCost > 0 }
    }

    private var selectedPoint: MonthlyEVCostPoint? {
        if let selectedPointID,
           let selected = points.first(where: { $0.id == selectedPointID }) {
            return selected
        }
        return points.last(where: { $0.sessionCount > 0 }) ?? points.last
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(points) { point in
                let isSelected = point.id == selectedPoint?.id

                BarMark(
                    x: .value("Ay", point.date, unit: .month),
                    y: .value("Tutar", point.totalCost)
                )
                .foregroundStyle(isSelected ? AppTheme.publicDCColor : AppTheme.publicACColor)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if isSelected, point.totalCost > 0 {
                        Text(NumberFormatting.currency(point.totalCost, code: currencyCode))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppTheme.heroBackground)
                            )
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(NumberFormatting.oneDecimal(amount))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectPoint(at: value.location, proxy: proxy, geometry: geometry)
                                }
                        )
                }
            }
            .frame(height: 190)

            if let selectedPoint {
                Text("Seçili ay: \(monthTitle(for: selectedPoint.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    metricTile(
                        title: "Ortalama TL/kWh",
                        value: selectedPoint.averageTLPerKWh.map {
                            NumberFormatting.tlPerKWh($0, currencyCode: currencyCode)
                        } ?? "Veri yok"
                    )
                    metricTile(
                        title: "Aylık enerji tüketimi",
                        value: selectedPoint.totalEnergyKWh > 0
                            ? NumberFormatting.kWh(selectedPoint.totalEnergyKWh)
                            : "Veri yok"
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Aylık maliyet grafiği için veri yok")
                .font(.subheadline.weight(.semibold))
            Text("Şarj kaydı ekledikçe ay bazlı EV maliyet trendi burada görünür.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func monthTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale.autoupdatingCurrent)
                .month(.wide)
                .year()
        )
    }

    private func selectPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotOriginX: CGFloat
        let plotWidth: CGFloat

        if #available(iOS 17.0, macOS 14.0, *) {
            guard let plotFrameAnchor = proxy.plotFrame else { return }
            let plotFrame = geometry[plotFrameAnchor]
            plotOriginX = plotFrame.origin.x
            plotWidth = proxy.plotSize.width
        } else {
            let plotFrame = geometry[proxy.plotAreaFrame]
            plotOriginX = plotFrame.origin.x
            plotWidth = proxy.plotAreaSize.width
        }

        let originX = location.x - plotOriginX
        guard originX >= 0, originX <= plotWidth,
              let date: Date = proxy.value(atX: originX) else {
            return
        }

        let selectedMonth = date.startOfMonth
        if let exact = points.first(where: { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }) {
            selectedPointID = exact.id
            return
        }

        let nearest = points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
        selectedPointID = nearest?.id
    }
}

#if DEBUG
struct MonthlyEVCostTrendCard_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let baseMonth = Date().startOfMonth
        let samplePoints: [MonthlyEVCostPoint] = (0..<6).compactMap { index in
            guard let date = calendar.date(byAdding: .month, value: index, to: baseMonth) else { return nil }
            let totalCost = Double((index + 1) * 350)
            let totalEnergy = Double((index + 1) * 28)
            return MonthlyEVCostPoint(
                date: date,
                totalCost: totalCost,
                totalEnergyKWh: totalEnergy,
                averageTLPerKWh: totalEnergy > 0 ? totalCost / totalEnergy : nil,
                sessionCount: index + 1
            )
        }

        VStack(spacing: 12) {
            MonthlyEVCostTrendCard(points: samplePoints, currencyCode: "TRY")
            MonthlyEVCostTrendCard(points: [], currencyCode: "TRY")
        }
        .padding()
    }
}
#endif
