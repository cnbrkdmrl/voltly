import SwiftUI

public struct MonthlyEVReportShareCardView: View {
    public let summary: MonthlyEVReportSummary

    public init(summary: MonthlyEVReportSummary) {
        self.summary = summary
    }

    public var body: some View {
        MonthlySummaryView(summary: summary, style: .shareCard)
    }
}

#if DEBUG
struct MonthlyEVReportShareCardView_Previews: PreviewProvider {
    static var previews: some View {
        MonthlyEVReportShareCardView(
            summary: MonthlyEVReportSummary(
                month: Date(),
                monthTitle: "Mart 2026",
                totalEnergyKWh: 253,
                sessionCount: 11,
                totalCost: 2726,
                averageTLPerKWh: 10.7,
                tlPer100Km: .exact(192),
                chargeDistribution: MonthlyChargeDistribution(
                    homeRatio: 20,
                    acRatio: 44,
                    dcRatio: 36
                ),
                gasolineSavingsPercent: 49,
                gasolineSavingsAmount: 98,
                currencyCode: "TRY"
            )
        )
        .frame(width: 360, height: 640)
        .padding()
    }
}
#endif
