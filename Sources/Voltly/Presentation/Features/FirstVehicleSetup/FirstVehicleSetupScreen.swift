import SwiftUI

public struct FirstVehicleSetupScreen: View {
    @StateObject private var viewModel: FirstVehicleSetupViewModel
    @State private var showingBrandSheet = false
    @State private var showingModelSheet = false
    @State private var showingTrimSheet = false
    @State private var showingYearSheet = false
    @State private var showSavedFeedback = false
    private let onCompletion: () -> Void

    public init(viewModel: FirstVehicleSetupViewModel, onCompletion: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompletion = onCompletion
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.defaultSectionSpacing) {
                header
                formCard
                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                }
            }
            .padding()
            .padding(.bottom, 92)
        }
        .background(AppTheme.surface.opacity(0.55))
        .safeAreaInset(edge: .bottom) {
            saveCTA
        }
        .sheet(isPresented: $showingBrandSheet) {
            OptionSelectionSheet(
                title: "Marka",
                options: viewModel.pickerBrands,
                selected: viewModel.selectedBrand,
                label: { $0 }
            ) { selected in
                viewModel.selectedBrand = selected
                viewModel.onBrandChanged()
            }
        }
        .sheet(isPresented: $showingModelSheet) {
            OptionSelectionSheet(
                title: "Model",
                options: viewModel.pickerModels,
                selected: viewModel.selectedModel,
                label: { $0 }
            ) { selected in
                viewModel.selectedModel = selected
                viewModel.onModelChanged()
            }
        }
        .sheet(isPresented: $showingTrimSheet) {
            OptionSelectionSheet(
                title: "Donanım / Trim",
                options: viewModel.pickerTrims,
                selected: viewModel.selectedTrim,
                label: { $0 }
            ) { selected in
                viewModel.selectedTrim = selected
                viewModel.onTrimChanged()
            }
        }
        .sheet(isPresented: $showingYearSheet) {
            OptionSelectionSheet(
                title: "Model Yılı",
                options: viewModel.pickerYears,
                selected: viewModel.selectedYear,
                label: { String($0) }
            ) { selected in
                viewModel.selectedYear = selected
                viewModel.onYearChanged()
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .top) {
            if showSavedFeedback {
                FloatingStatusBanner(title: "Araç kaydedildi")
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("İlk Araç Kurulumu")
                .font(.title3.weight(.bold))
            Text("İlk şarj analizlerini doğru gösterebilmemiz için araç bilgilerini ekle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SelectionFieldButton(
                title: "Marka",
                value: viewModel.selectedBrand,
                placeholder: "Marka sec"
            ) {
                showingBrandSheet = true
            }

            SelectionFieldButton(
                title: "Model",
                value: viewModel.selectedModel,
                placeholder: "Model sec"
            ) {
                showingModelSheet = true
            }

            SelectionFieldButton(
                title: "Donanım / Trim",
                value: viewModel.selectedTrim,
                placeholder: "Donanım sec"
            ) {
                showingTrimSheet = true
            }

            SelectionFieldButton(
                title: "Model Yılı",
                value: String(viewModel.selectedYear),
                placeholder: "Yıl sec"
            ) {
                showingYearSheet = true
            }

            technicalSummary
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var saveCTA: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.softImpact()
                if viewModel.saveFirstVehicle() {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showSavedFeedback = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 650_000_000)
                        await MainActor.run {
                            onCompletion()
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Aracı Kaydet ve Devam Et")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canSave ? AppTheme.publicACColor : AppTheme.publicACColor.opacity(0.45))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.canSave)

            if let warning = viewModel.formValidationMessage, !viewModel.isSaving {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var technicalSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sistem Teknik Verisi")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let spec = viewModel.selectedSpec {
                Text("Araç gücü: \(Int(spec.enginePowerKW)) kW (\(Int(spec.enginePowerHP)) hp)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Batarya kapasitesi: \(NumberFormatting.oneDecimal(spec.batteryCapacityKWh)) kWh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("AC maksimum hız: \(NumberFormatting.oneDecimal(spec.acMaxChargingKW)) kW")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("DC maksimum hız: \(NumberFormatting.oneDecimal(spec.dcMaxChargingKW)) kW")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Ortalama tüketim: \(NumberFormatting.kWhPer100Km(spec.factoryConsumptionKWh100km))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Bu değerler araç kataloğundan otomatik uygulanır.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Bu model yılı için katalog verisi bulunamadı.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
struct FirstVehicleSetupScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FirstVehicleSetupScreen(
                viewModel: FirstVehicleSetupViewModel(environment: try! AppEnvironment.live(inMemory: true)),
                onCompletion: {}
            )
        }
    }
}
#endif
