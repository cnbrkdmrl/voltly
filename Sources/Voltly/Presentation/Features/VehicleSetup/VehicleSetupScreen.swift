import SwiftUI

public struct VehicleSetupScreen: View {
    @StateObject private var viewModel: VehicleSetupViewModel
    @State private var hasTriggeredCompletion = false
    @State private var showingBrandSheet = false
    @State private var showingModelSheet = false
    @State private var showingTrimSheet = false
    @State private var showingYearSheet = false
    @State private var savedBannerMessage: String?
    private let onCompletion: (() -> Void)?

    public init(viewModel: VehicleSetupViewModel, onCompletion: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompletion = onCompletion
    }

    public var body: some View {
        Form {
            Section("Arac Ekle") {
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
                    title: "Donanim / Trim",
                    value: viewModel.selectedTrim,
                    placeholder: "Donanim sec"
                ) {
                    showingTrimSheet = true
                }

                SelectionFieldButton(
                    title: "Yil",
                    value: String(viewModel.selectedYear),
                    placeholder: "Yil sec"
                ) {
                    showingYearSheet = true
                }

                technicalSummary
                labeledTextField(
                    title: "Renk kodu (opsiyonel)",
                    placeholder: "Orn. #1F5AFF",
                    text: $viewModel.colorCode
                )

                Button("Araci Kaydet") {
                    Haptics.softImpact()
                    viewModel.saveVehicle()
                }
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .foregroundStyle(messageColor(for: message))
                }
            }

            Section("Kayitli Araclar") {
                if viewModel.vehicles.isEmpty {
                    Text("Henuz arac yok")
                }
                ForEach(viewModel.vehicles) { vehicle in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(vehicle.brand) \(vehicle.model) \(vehicle.year)")
                                .font(.headline)
                            Spacer()
                            if vehicle.isActive {
                                Text("Aktif")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 10) {
                            vehicleMetaTag("Batarya", "\(NumberFormatting.oneDecimal(vehicle.batteryCapacityKWh)) kWh")
                            vehicleMetaTag("AC", vehicle.acMaxChargingKW.map { "\(NumberFormatting.oneDecimal($0)) kW" } ?? "-")
                            vehicleMetaTag("DC", vehicle.dcMaxChargingKW.map { "\(NumberFormatting.oneDecimal($0)) kW" } ?? "-")
                        }

                        HStack(spacing: 10) {
                            vehicleMetaTag("Tuketim", vehicle.factoryConsumptionKWh100km.map(NumberFormatting.kWhPer100Km) ?? "-")
                            vehicleMetaTag("Renk", vehicle.colorCode ?? "-")
                        }

                        HStack {
                            Button("Aktif Yap") { viewModel.setActive(vehicle) }
                            Button("Sil", role: .destructive) { viewModel.delete(vehicle) }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.vehicleSetup)
        .onAppear { viewModel.loadVehicles() }
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
                title: "Donanim / Trim",
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
                title: "Yil",
                options: viewModel.pickerYears,
                selected: viewModel.selectedYear,
                label: { String($0) }
            ) { selected in
                viewModel.selectedYear = selected
                viewModel.onYearChanged()
            }
        }
        .onChange(of: viewModel.vehicles) { _, vehicles in
            guard !hasTriggeredCompletion, !vehicles.isEmpty else { return }
            hasTriggeredCompletion = true
            onCompletion?()
        }
        .onChange(of: viewModel.message) { _, message in
            guard let message, isSuccessMessage(message) else { return }
            presentSavedBanner(message)
        }
        .overlay(alignment: .top) {
            if let savedBannerMessage {
                FloatingStatusBanner(title: savedBannerMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func vehicleMetaTag(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var technicalSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sistem Teknik Verisi")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let spec = viewModel.selectedSpec {
                Text("Arac gucu: \(Int(spec.enginePowerKW)) kW (\(Int(spec.enginePowerHP)) hp)")
                    .font(.footnote.weight(.semibold))
                Text("Batarya kapasitesi: \(NumberFormatting.oneDecimal(spec.batteryCapacityKWh)) kWh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("AC maksimum hiz: \(NumberFormatting.oneDecimal(spec.acMaxChargingKW)) kW")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("DC maksimum hiz: \(NumberFormatting.oneDecimal(spec.dcMaxChargingKW)) kW")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Ortalama tuketim: \(NumberFormatting.kWhPer100Km(spec.factoryConsumptionKWh100km))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Bu degerler katalogdan otomatik uygulanir.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Bu secim icin teknik veri bulunamadi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 2)
    }

    private func isSuccessMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("kaydedildi") ||
            normalized.contains("hazir") ||
            normalized.contains("hazır") ||
            normalized.contains("silindi")
    }

    private func messageColor(for message: String) -> Color {
        let normalized = message.lowercased()
        if normalized.contains("kaydedildi") ||
            normalized.contains("hazir") ||
            normalized.contains("hazır") ||
            normalized.contains("silindi") {
            return .green
        }
        return .red
    }

    private func presentSavedBanner(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            savedBannerMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if savedBannerMessage == message {
                        savedBannerMessage = nil
                    }
                }
            }
        }
    }
}
