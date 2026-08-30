import SwiftUI

public struct ChargingDefaultsView: View {
    @ObservedObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Yedek elektrik fiyatı", text: $viewModel.defaultElectricityPricePerKWh)
                            .voltlyDecimalKeyboard()
                        Text("TL / kWh")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Yedek Fiyat")
            } footer: {
                Text("Bir ev profiline fiyat girilmişse o fiyat kullanılır. Profil fiyatı boşsa bu yedek değer devreye girer.")
            }

            Section("Ev Profilleri") {
                homeProfileEditor(profileID: 1, title: "1. Ev")

                Toggle(
                    "2. evi etkinleştir",
                    isOn: Binding(
                        get: { viewModel.secondHomeEnabled },
                        set: { viewModel.setHomeProfileEnabled(profileID: 2, isEnabled: $0) }
                    )
                )

                if viewModel.secondHomeEnabled {
                    homeProfileEditor(profileID: 2, title: "2. Ev")

                    Toggle(
                        "3. evi etkinleştir",
                        isOn: Binding(
                            get: { viewModel.thirdHomeEnabled },
                            set: { viewModel.setHomeProfileEnabled(profileID: 3, isEnabled: $0) }
                        )
                    )

                    if viewModel.thirdHomeEnabled {
                        homeProfileEditor(profileID: 3, title: "3. Ev")
                    }
                }
            }

            if !viewModel.enabledHomeProfiles.isEmpty {
                Section("Şarj Kayıtlarında Otomatik Seçim") {
                    Picker(
                        "Varsayılan ev",
                        selection: Binding(
                            get: { viewModel.homeChargingPreferences.defaultProfileID },
                            set: { viewModel.setDefaultHomeProfile(id: $0) }
                        )
                    ) {
                        ForEach(viewModel.enabledHomeProfiles) { profile in
                            Text(profile.displayName).tag(profile.id)
                        }
                    }
                }
            }

            Section {
                Button("Şarj varsayılanlarını kaydet") {
                    viewModel.saveChargingPreferences()
                }
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .foregroundStyle(messageColor(for: message))
                }
            }
        }
        .listStyle(preferredListStyle)
        .navigationTitle("Şarj Varsayılanları")
        .modifier(InlineTitleModifier())
    }

    @ViewBuilder
    private func homeProfileEditor(profileID: Int, title: String) -> some View {
        if let profile = viewModel.homeProfile(for: profileID) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if viewModel.homeChargingPreferences.defaultProfileID == profileID {
                        Text("Varsayılan")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                TextField(
                    "\(profileID). ev adı",
                    text: Binding(
                        get: { viewModel.homeProfile(for: profileID)?.name ?? "" },
                        set: { viewModel.setHomeProfileName(profileID: profileID, name: $0) }
                    )
                )

                TextField(
                    "\(profileID). ev konumu",
                    text: Binding(
                        get: { viewModel.homeProfile(for: profileID)?.location ?? "" },
                        set: { viewModel.setHomeProfileLocation(profileID: profileID, location: $0) }
                    )
                )

                HStack(spacing: 8) {
                    TextField(
                        "\(profileID). ev elektrik fiyatı",
                        text: Binding(
                            get: { viewModel.homeTariffText(for: profileID) },
                            set: { viewModel.setHomeTariffText($0, profileID: profileID) }
                        )
                    )
                    .voltlyDecimalKeyboard()

                    Text("TL / kWh")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if !viewModel.homeTariffText(for: profileID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    Text("Ev elektrik fiyatı: \(viewModel.homeTariffText(for: profileID)) TL / kWh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let tariff = profile.tariffPricePerKWh, tariff > 0 {
                    Text("Ev elektrik fiyatı: \(NumberFormatting.oneDecimal(tariff)) TL / kWh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func messageColor(for message: String) -> Color {
        let normalized = message.lowercased()
        if normalized.contains("kaydedildi") ||
            normalized.contains("hazir") ||
            normalized.contains("hazır") {
            return .green
        }
        return .red
    }

    private var preferredListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .automatic
        #endif
    }
}

private struct InlineTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

#if DEBUG
@MainActor
struct ChargingDefaultsView_Previews: PreviewProvider {
    static var previews: some View {
        let environment = try! AppEnvironment.live(inMemory: true)
        let viewModel = SettingsViewModel(environment: environment)
        return NavigationStack {
            ChargingDefaultsView(viewModel: viewModel)
        }
    }
}
#endif
