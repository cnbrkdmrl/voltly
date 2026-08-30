import SwiftUI

public struct RealEVCostScreen: View {
    @StateObject private var viewModel: RealEVCostViewModel

    public init(viewModel: RealEVCostViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UIConstants.defaultSectionSpacing) {
                    if !viewModel.hasActiveVehicle {
                        ContentUnavailableView(
                            "Gerçek maliyet için aktif araç gerekli",
                            systemImage: "car.fill",
                            description: Text("Ayarlar > Araç Yönetimi ekranından aktif bir araç seç.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                    } else {
                        RealEVCostSummaryCard(
                            summary: viewModel.summary,
                            fallbackMessage: viewModel.fallbackMessage
                        )
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
            .navigationTitle(L10n.realEVCost)
            .onAppear {
                viewModel.load()
            }
        }
    }
}

#if DEBUG
@MainActor
struct RealEVCostScreen_Previews: PreviewProvider {
    static var previews: some View {
        let environment = try! AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Renault",
            model: "Megane E-Tech",
            year: 2024,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 17
        )
        _ = try? environment.createVehicleUseCase.execute(vehicle)
        _ = try? environment.setActiveVehicleUseCase.execute(id: vehicle.id)
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-4 * 86_400),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Garaj",
                priceTotal: 80,
                energyKWh: 16,
                socStart: 22,
                socEnd: 64,
                odometerKM: 12_000
            )
        )
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-2 * 86_400),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Bursa AVM",
                priceTotal: 130,
                energyKWh: 18,
                socStart: 29,
                socEnd: 79,
                odometerKM: 12_100
            )
        )
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: Date.now.addingTimeInterval(-1 * 86_400),
                chargeMethod: .publicDC,
                stationBrand: "Trugo",
                locationName: "Balıkesir",
                priceTotal: 234,
                energyKWh: 22,
                socStart: 18,
                socEnd: 82,
                odometerKM: 12_230
            )
        )

        return RealEVCostScreen(
            viewModel: RealEVCostViewModel(environment: environment)
        )
    }
}
#endif
