import SwiftUI

public struct ChargeHabitCard: View {
    private let summary: ChargeHabitSummary?
    private let analysisConfidence: AnalysisConfidenceReport?
    private let onApplyPlan: (() -> Void)?

    public init(
        summary: ChargeHabitSummary?,
        analysisConfidence: AnalysisConfidenceReport? = nil,
        onApplyPlan: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.analysisConfidence = analysisConfidence
        self.onApplyPlan = onApplyPlan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Şarj alışkanlığın")
                .font(.headline)

            if let summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.headline)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.recommendationText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let analysisConfidence {
                    AnalysisConfidenceView(confidence: analysisConfidence)
                }

                ForEach(summary.items.sorted(by: sortHabitItems(_:_:))) { item in
                    habitRow(item)
                }

                if let targetSummaryText = summary.targetSummaryText {
                    Label(targetSummaryText, systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.publicACColor)
                }

                if let cta = summary.cta {
                    Button {
                        onApplyPlan?()
                    } label: {
                        HStack(spacing: 10) {
                            Text(cta.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(cta.suggestedChargeType.chargeMethod.titleTR)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(cta.suggestedChargeType.chargeMethod.uiColor.opacity(0.16))
                                .foregroundStyle(cta.suggestedChargeType.chargeMethod.uiColor)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cta.suggestedChargeType.chargeMethod.uiColor)
                    .accessibilityLabel("\(cta.title), önerilen yöntem \(cta.suggestedChargeType.chargeMethod.titleTR)")
                    .accessibilityHint("Şarj ekleme ekranını önerilen planla açar")
                }
            } else {
                EmptyInfoCard(
                    title: "Alışkanlık analizi için veri yok",
                    subtitle: "Yüzde dağılımı için bu ay en az 1 şarj kaydı gerekli.",
                    iconName: "chart.bar.xaxis"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private func sortHabitItems(_ lhs: ChargeHabitItem, _ rhs: ChargeHabitItem) -> Bool {
        let order: [ChargeMethod] = [.home, .publicAC, .publicDC]
        let lhsIndex = order.firstIndex(of: lhs.method) ?? .max
        let rhsIndex = order.firstIndex(of: rhs.method) ?? .max
        return lhsIndex < rhsIndex
    }

    private func habitRow(_ item: ChargeHabitItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(item.method.titleTR)
                    .font(.subheadline.weight(.semibold))
                if let targetPercent = item.targetPercent {
                    Text(targetLabelText(for: item.method, targetPercent: targetPercent))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(item.method.uiColor.opacity(0.14))
                        .foregroundStyle(item.method.uiColor)
                        .clipShape(Capsule())
                }
                Spacer()
                Text("%\(Int(item.percent.rounded()))")
                    .font(.subheadline.weight(.bold))
            }

            ProgressView(value: max(0, min(100, item.percent)), total: 100)
                .tint(item.method.uiColor)
        }
    }

    private func targetLabelText(for method: ChargeMethod, targetPercent: Double) -> String {
        switch method {
        case .publicDC:
            return "Hedef %\(Int(targetPercent.rounded()))"
        case .publicAC:
            return "En az %\(Int(targetPercent.rounded()))"
        case .home:
            return "Denge noktası"
        }
    }
}

#if DEBUG
struct ChargeHabitCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChargeHabitCard(
                summary: ChargeHabitSummary(
                    items: [
                        ChargeHabitItem(method: .home, percent: 6, targetPercent: nil),
                        ChargeHabitItem(method: .publicAC, percent: 18, targetPercent: 25),
                        ChargeHabitItem(method: .publicDC, percent: 76, targetPercent: 60)
                    ],
                    headline: "DC payin maliyeti yukari cekiyor",
                    recommendationText: "DC kullanimin agir basiyor. Siradaki seansi AC secmek birim maliyeti daha dengeli tutabilir.",
                    targetSummaryText: "DC %76, hedef %60",
                    cta: ChargeHabitCTA(title: "Planı uygula", suggestedChargeType: .ac)
                )
            )

            ChargeHabitCard(summary: nil)
        }
        .padding()
    }
}
#endif
