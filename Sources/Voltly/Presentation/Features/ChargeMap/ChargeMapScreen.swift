import MapKit
import SwiftUI

public struct ChargeMapScreen: View {
    @StateObject private var viewModel: ChargeMapViewModel

    public init(viewModel: ChargeMapViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var mapPositionBinding: Binding<MapCameraPosition> {
        Binding(
            get: { .region(viewModel.region) },
            set: { position in
                if let region = position.region {
                    viewModel.region = region
                }
            }
        )
    }

    public var body: some View {
        ZStack {
            Map(position: mapPositionBinding, interactionModes: .all) {
                ForEach(viewModel.pins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                        Button {
                            viewModel.selectedPinID = pin.id
                        } label: {
                            ChargeMapAnnotationView(
                                pin: pin,
                                isSelected: viewModel.selectedPinID == pin.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if viewModel.isLoading {
                ProgressView("Konumlar hazırlanıyor...")
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.pins.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    "Haritada gösterilecek kayıt yok",
                    systemImage: "map",
                    description: Text("Lokasyon bilgisi içeren bir şarj kaydı ekledikten sonra harita otomatik dolacaktır.")
                )
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(L10n.chargeMap)
        .toolbar {
            ToolbarItem(placement: .voltlyPrimaryAction) {
                Button {
                    viewModel.fitAllPins()
                } label: {
                    Image(systemName: "scope")
                }
                .disabled(viewModel.pins.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pin = viewModel.selectedPin {
                pinInfoCard(pin)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func pinInfoCard(_ pin: ChargeMapPin) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pin.stationDisplayName)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            Text(pin.chargeMethod.titleTR)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(pin.chargeMethod.uiColor)

            Divider()

            HStack(spacing: 10) {
                infoTile("Enerji", pin.energyKWh.map(NumberFormatting.kWh) ?? "Veri yok")
                infoTile("Toplam", NumberFormatting.currency(pin.totalPrice, code: pin.currencyCode))
                infoTile("TL/kWh", pin.tlPerKWh.map { NumberFormatting.tlPerKWh($0, currencyCode: pin.currencyCode) } ?? "Veri yok")
            }

            if pin.isApproximateLocation {
                Text("Konum metni çözümlenemedi, yaklaşık pin kullanılıyor.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(UIConstants.cardInnerPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    private func infoTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppTheme.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#if DEBUG
@MainActor
struct ChargeMapScreen_Previews: PreviewProvider {
    static var previews: some View {
        let environment = try! AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        _ = try? environment.createVehicleUseCase.execute(vehicle)
        _ = try? environment.setActiveVehicleUseCase.execute(id: vehicle.id)
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                chargeMethod: .publicDC,
                stationBrand: "Lumicle",
                locationName: "41.0160, 28.9798",
                priceTotal: 141,
                energyKWh: 12.3,
                socStart: 20,
                socEnd: 61
            )
        )
        _ = try? environment.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                chargeMethod: .home,
                stationBrand: "Ev Wallbox",
                locationName: "39.9208, 32.8541",
                priceTotal: 88,
                energyKWh: 17.1,
                socStart: 42,
                socEnd: 80
            )
        )

        return NavigationStack {
            ChargeMapScreen(viewModel: ChargeMapViewModel(environment: environment))
        }
    }
}
#endif
