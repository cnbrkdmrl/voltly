import SwiftUI

public struct PersonalRecordDetailScreen: View {
    private let item: PersonalRecordItem

    public init(item: PersonalRecordItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                ChargingSessionRowCard(session: item.session)
                metadataCard
            }
            .padding()
        }
        .navigationTitle("Seans Detayi")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(item.type.title, systemImage: item.type.iconName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(item.metricText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accentColor)
            }

            Text(item.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let note = item.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kayit Bilgisi")
                .font(.headline)

            metadataRow("Veri kaynagi", confidenceSourceTitle)
            metadataRow("Güven skoru", "\(item.confidence.score)/100")
            metadataRow("Yontem", item.session.chargeMethod.titleTR)
            metadataRow("Tarih", NumberFormatting.dateTime(item.session.sessionDate))

            if let notes = item.session.notes, !notes.isEmpty {
                metadataRow("Not", notes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    private var confidenceSourceTitle: String {
        switch item.confidence.source {
        case .real:
            return "Gercek veri"
        case .mixed:
            return "Karma veri"
        case .estimated:
            return "Tahmini veri"
        case .unavailable:
            return "Veri yok"
        }
    }

    private var accentColor: Color {
        switch item.type {
        case .cheapestCharge, .mostEfficientCharge, .shortestSession:
            return AppTheme.homeColor
        case .mostExpensiveCharge, .longestSession:
            return AppTheme.publicDCColor
        case .highestEnergySession:
            return AppTheme.publicACColor
        }
    }
}
