import Charts
import SwiftUI

public struct TLPerKWhTrendCard: View {
    private let points: [TLPerKWhTrendPoint]
    private let currencyCode: String

    public init(
        points: [TLPerKWhTrendPoint],
        currencyCode: String
    ) {
        self.points = points
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TL/kWh Trendi (Son 30 Gün)")
                .font(.headline)

            if points.isEmpty {
                emptyState
            } else {
                chartContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(points) { point in
                AreaMark(
                    x: .value("Tarih", point.date),
                    y: .value("TL/kWh", point.averageTLPerKWh)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            AppTheme.publicACColor.opacity(0.25),
                            AppTheme.publicACColor.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Tarih", point.date),
                    y: .value("TL/kWh", point.averageTLPerKWh)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(AppTheme.publicACColor)

                PointMark(
                    x: .value("Tarih", point.date),
                    y: .value("TL/kWh", point.averageTLPerKWh)
                )
                .foregroundStyle(AppTheme.publicACColor)
                .symbolSize(24)
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
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 180)

            if let latest = points.last {
                Text("Son değer: \(NumberFormatting.tlPerKWh(latest.averageTLPerKWh, currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Son 30 günde TL/kWh verisi yok")
                .font(.subheadline.weight(.semibold))
            Text("Enerji bilgisi olan şarj kayıtlarıyla trend burada görünür.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

#if DEBUG
struct TLPerKWhTrendCard_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let now = Date()
        let samplePoints: [TLPerKWhTrendPoint] = [
            TLPerKWhTrendPoint(
                date: calendar.date(byAdding: .day, value: -6, to: now) ?? now,
                averageTLPerKWh: 9.8,
                sessionCount: 1
            ),
            TLPerKWhTrendPoint(
                date: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
                averageTLPerKWh: 10.6,
                sessionCount: 2
            ),
            TLPerKWhTrendPoint(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                averageTLPerKWh: 9.2,
                sessionCount: 1
            ),
            TLPerKWhTrendPoint(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                averageTLPerKWh: 11.1,
                sessionCount: 1
            )
        ]

        VStack(spacing: 12) {
            TLPerKWhTrendCard(points: samplePoints, currencyCode: "TRY")
            TLPerKWhTrendCard(points: [], currencyCode: "TRY")
        }
        .padding()
    }
}
#endif
