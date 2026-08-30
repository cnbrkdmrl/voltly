import SwiftUI

public struct MonthlyEVReportScreen: View {
    @StateObject private var viewModel: MonthlyEVReportViewModel
    @State private var showingMonthSheet = false

    public init(viewModel: MonthlyEVReportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: UIConstants.defaultSectionSpacing) {
                if !viewModel.hasActiveVehicle {
                    ContentUnavailableView(
                        "Rapor için aktif araç gerekli",
                        systemImage: "car.fill",
                        description: Text("Ayarlar > Araç Yönetimi bölümünden aktif araç seç.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                } else {
                    monthPickerSection
                    MonthlySummaryView(summary: viewModel.summary, style: .appCard)
                    if viewModel.exportPDFEnabled {
                        shareSection
                    } else {
                        exportDisabledSection
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                }
            }
            .padding()
        }
        .navigationTitle(L10n.monthlyEVReport)
        .sheet(isPresented: $showingMonthSheet) {
            OptionSelectionSheet(
                title: "Dönem",
                options: viewModel.availableMonths,
                selected: viewModel.selectedMonth
            ) { month in
                viewModel.monthLabel(for: month)
            } onSelect: { month in
                viewModel.selectMonth(month)
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var monthPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dönem")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            SelectionFieldButton(
                title: "Ay seç",
                value: viewModel.monthLabel(for: viewModel.selectedMonth),
                placeholder: "Ay sec"
            ) {
                showingMonthSheet = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paylaş")
                .font(.headline)

            #if os(iOS)
            VStack(alignment: .leading, spacing: 6) {
                Text("Kart oranı")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(MonthlySummaryExportAspectRatio.allCases, id: \.self) { ratio in
                        Button {
                            viewModel.setExportAspectRatio(ratio)
                        } label: {
                            Text(ratio.titleTR)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.exportAspectRatio == ratio
                                        ? AppTheme.publicACColor.opacity(0.22)
                                        : AppTheme.overlaySurface
                                )
                                .foregroundStyle(
                                    viewModel.exportAspectRatio == ratio
                                        ? AppTheme.publicACColor
                                        : .secondary
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            #endif

            if let summary = viewModel.summary {
                MonthlySummaryView(summary: summary, style: .shareCard)
                    .frame(height: 500)
            }

            #if os(iOS)
            if let image = viewModel.shareImage,
               let imageData = image.pngData() {
                ShareLink(
                    item: imageData,
                    preview: SharePreview("Voltly EV Report", image: Image(uiImage: image))
                ) {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.trackReportShared()
                })
            } else {
                Text("Paylaşım kartı hazırlanıyor...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var exportDisabledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paylaş")
                .font(.headline)
            Text("Paylaşım / PDF dışa aktarım modülü bu sürümde kapalı.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }
}

#if DEBUG
@MainActor
struct MonthlyEVReportScreen_Previews: PreviewProvider {
    static var previews: some View {
        let environment = try! AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Togg",
            model: "T10X",
            year: 2025,
            batteryCapacityKWh: 52.4,
            factoryConsumptionKWh100km: 17.8
        )
        _ = try? environment.createVehicleUseCase.execute(vehicle)
        _ = try? environment.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-12 * 86_400),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Bursa",
                priceTotal: 460,
                energyKWh: 41,
                socStart: 18,
                socEnd: 86,
                odometerKM: 11_900
            )
        )
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-5 * 86_400),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Balıkesir",
                priceTotal: 210,
                energyKWh: 24,
                socStart: 34,
                socEnd: 79,
                odometerKM: 12_050
            )
        )
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-1 * 86_400),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Garaj",
                priceTotal: 95,
                energyKWh: 20,
                socStart: 42,
                socEnd: 82,
                odometerKM: 12_180
            )
        )

        return NavigationStack {
            MonthlyEVReportScreen(viewModel: MonthlyEVReportViewModel(environment: environment))
        }
    }
}
#endif
