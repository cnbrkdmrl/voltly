import SwiftUI

public struct ExperimentSuggestionCard: View {
    private let suggestion: ExperimentSuggestion
    private let onApplySuggestion: ((SuggestedChargeDefaultType) -> Void)?

    public init(
        suggestion: ExperimentSuggestion,
        onApplySuggestion: ((SuggestedChargeDefaultType) -> Void)? = nil
    ) {
        self.suggestion = suggestion
        self.onApplySuggestion = onApplySuggestion
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bu Haftaki Deneme")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: suggestion.type.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(suggestion.type.accentMethod.uiColor)
                    .frame(width: 18, height: 18)
                    .padding(8)
                    .background(suggestion.type.accentMethod.uiColor.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                    Text(suggestion.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text("Önerilen başlangıç: \(suggestion.suggestedChargeType.chargeMethod.titleTR)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(suggestion.suggestedChargeType.chargeMethod.uiColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(suggestion.suggestedChargeType.chargeMethod.uiColor.opacity(0.14))
                .clipShape(Capsule())
                .accessibilityLabel("Önerilen başlangıç yöntemi \(suggestion.suggestedChargeType.chargeMethod.titleTR)")

            if let onApplySuggestion {
                Button {
                    Haptics.softImpact()
                    onApplySuggestion(suggestion.suggestedChargeType)
                } label: {
                    HStack(spacing: 10) {
                        Text("Bu planla şarj ekle")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(suggestion.suggestedChargeType.chargeMethod.uiColor)
                .accessibilityHint("Şarj ekleme ekranını önerilen yöntemle açar")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

public struct ExperimentResultCard: View {
    private let result: ExperimentResultInsight

    public init(result: ExperimentResultInsight) {
        self.result = result
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deneme Sonucu")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(result.type.accentMethod.uiColor)
                    .frame(width: 18, height: 18)
                    .padding(8)
                    .background(result.type.accentMethod.uiColor.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                    Text(result.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
struct ExperimentSuggestionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ExperimentSuggestionCard(
                suggestion: ExperimentSuggestion(
                    type: .increaseAC,
                    title: "Bu hafta daha fazla AC dene",
                    message: "AC payın düşük görünüyor. Bu hafta birkaç seansı AC planlamak maliyet ritmini sakinleştirebilir.",
                    suggestedChargeType: .ac
                )
            )

            ExperimentResultCard(
                result: ExperimentResultInsight(
                    id: "preview",
                    type: .increaseAC,
                    title: "AC denemesi olumlu gidiyor",
                    message: "Bu hafta AC ağırlığını artırarak yaklaşık ₺280 tasarruf ettin."
                )
            )
        }
        .padding()
    }
}
#endif
