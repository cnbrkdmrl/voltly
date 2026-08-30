import SwiftUI

public struct GoalsSettingsView: View {
    @ObservedObject private var viewModel: SettingsViewModel
    @State private var monthlySpendingTarget = ""
    @State private var dcUsageRatioTarget = ""
    @State private var monthlyEntryTarget = ""

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            if let suggestion = viewModel.suggestedGoalSet {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(suggestion.title)
                                .font(.headline)
                            Text(suggestion.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(suggestion.goals) { goal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.type.titleTR)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(targetSummary(for: goal))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.publicACColor)
                                Text(goal.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        HStack(spacing: 10) {
                            Button("Kabul et") {
                                viewModel.acceptSuggestedGoals()
                                syncFromViewModel()
                                Haptics.success()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Düzenle") {
                                applySuggestedGoalsToInputs()
                                Haptics.softImpact()
                            }
                            .buttonStyle(.bordered)

                            Button("Bu ay pas geç") {
                                viewModel.skipSuggestedGoals()
                                Haptics.softImpact()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Text("Bu hedefler aylik analizlerinle birlikte calisir. Bos birakilan alanlar hedef olarak kullanilmaz.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Aylık Toplam Harcama") {
                TextField("Örn: 2500", text: $monthlySpendingTarget)
                    .voltlyDecimalKeyboard()
                Text("Bu ay toplam şarj harcamanı bu limitin altında tutmaya çalış.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("DC Şarj Oranı") {
                TextField("Örn: 35", text: $dcUsageRatioTarget)
                    .voltlyDecimalKeyboard()
                Text("DC (hızlı) şarj, batarya sağlığını daha çok etkiler ve genellikle daha pahalıdır. Aylık DC kullanımını belirli bir yüzdenin altında tutmak için hedef belirle. Ev ve AC istasyon şarjları bu orana dahil edilmez.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Aylık Kayıt Düzeni") {
                TextField("Örn: 8", text: $monthlyEntryTarget)
                    .voltlyDecimalKeyboard()
                Text("Bu ay kaç şarj kaydı girmeyi hedeflediğini takip eder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Hedefleri kaydet") {
                    Haptics.softImpact()
                    viewModel.saveGoals(
                        monthlySpendingTargetText: monthlySpendingTarget,
                        dcUsageRatioTargetText: dcUsageRatioTarget,
                        monthlyEntryTargetText: monthlyEntryTarget
                    )
                }
            }
        }
        .navigationTitle("Hedefler")
        .onAppear {
            viewModel.refreshGoalSuggestions()
            syncFromViewModel()
        }
    }

    private func syncFromViewModel() {
        monthlySpendingTarget = viewModel.goalTargetText(for: .monthlySpending)
        dcUsageRatioTarget = viewModel.goalTargetText(for: .dcUsageRatio)
        monthlyEntryTarget = viewModel.goalTargetText(for: .monthlyChargeEntries)
    }

    private func applySuggestedGoalsToInputs() {
        monthlySpendingTarget = viewModel.suggestedGoalTargetText(for: .monthlySpending)
        dcUsageRatioTarget = viewModel.suggestedGoalTargetText(for: .dcUsageRatio)
        monthlyEntryTarget = viewModel.suggestedGoalTargetText(for: .monthlyChargeEntries)
    }

    private func targetSummary(for goal: SuggestedGoal) -> String {
        switch goal.type {
        case .monthlySpending:
            return "Öneri: \(NumberFormatting.currency(goal.targetValue, code: viewModel.selectedCurrencyCode))"
        case .dcUsageRatio:
            return "Öneri: %\(Int(goal.targetValue.rounded()))"
        case .monthlyChargeEntries:
            return "Öneri: \(Int(goal.targetValue.rounded())) kayıt"
        }
    }
}
