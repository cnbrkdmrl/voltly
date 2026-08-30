import SwiftUI

public struct ChargingSessionRowCard: View {
    private let session: ChargingSession
    private let compact: Bool
    private let scoreReport: ChargeSessionScoreReport?

    public init(
        session: ChargingSession,
        compact: Bool = false,
        scoreReport: ChargeSessionScoreReport? = nil
    ) {
        self.session = session
        self.compact = compact
        self.scoreReport = scoreReport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(session.chargeMethod.titleTR, systemImage: session.chargeMethod.iconName)
                    .foregroundStyle(session.chargeMethod.uiColor)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(NumberFormatting.currency(session.priceTotal, code: session.currencyCode))
                    .font(.subheadline.weight(.bold))
            }

            Text(session.stationDisplayName)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(NumberFormatting.dateTime(session.sessionDate))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let scoreReport {
                ChargeSessionScoreSummaryView(report: scoreReport)
            }

            HStack(spacing: 10) {
                metricPill("Şarj Yüzdesi", "\(Int(session.socStart))% → \(Int(session.socEnd))%")
                metricPill("Enerji", session.energyKWh.map(NumberFormatting.kWh) ?? "-")
            }

            HStack(spacing: 10) {
                metricPill("TL/kWh", session.tlPerKWh.map { NumberFormatting.tlPerKWh($0, currencyCode: session.currencyCode) } ?? "-")
                if !compact {
                    metricPill("Süre", session.durationMin.map { "\($0) dk" } ?? "-")
                }
            }
        }
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private func metricPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppTheme.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#if DEBUG
struct ChargingSessionRowCard_Previews: PreviewProvider {
    static var previews: some View {
        ChargingSessionRowCard(
            session: ChargingSession(
                vehicleID: UUID(),
                sessionDate: .now,
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadıköy Sahil",
                priceTotal: 430,
                energyKWh: 39.4,
                socStart: 24,
                socEnd: 81,
                durationMin: 58
            )
        )
        .padding()
    }
}
#endif
