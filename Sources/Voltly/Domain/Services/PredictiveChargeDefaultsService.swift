import Foundation

public enum QuickChargePresetKind: String, Equatable {
    case homeRoutine
    case publicACFavorite
    case roadTripDC
}

public struct QuickChargePresetPrefill: Equatable {
    public let chargeMethod: ChargeMethod
    public let selectedHomeProfileID: Int?
    public let stationBrand: String?
    public let locationName: String?
    public let tariffPricePerKWh: Double?
    public let suggestedSOCStart: Double?
    public let suggestedSOCEnd: Double?
    public let suggestedDurationMinutes: Double?
}

public struct QuickChargePreset: Identifiable, Equatable {
    public let id: String
    public let kind: QuickChargePresetKind
    public let title: String
    public let subtitle: String
    public let detail: String
    public let prefill: QuickChargePresetPrefill

    public init(
        id: String,
        kind: QuickChargePresetKind,
        title: String,
        subtitle: String,
        detail: String,
        prefill: QuickChargePresetPrefill
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.prefill = prefill
    }
}

public struct PredictiveChargeDefaultsReport: Equatable {
    public let dominantMethod: ChargeMethod?
    public let dominantOperator: String?
    public let dominantStation: String?
    public let timeOfDayHint: String?
    public let quickPresets: [QuickChargePreset]
}

public struct PredictiveChargeDefaultsService {
    public init() {}

    public func makeReport(
        sessions: [ChargingSession],
        availableHomeProfiles: [HomeChargingProfile],
        selectedHomeProfileID: Int,
        defaultElectricityTariffPerKWh: Double?,
        referenceDate _: Date = .now
    ) -> PredictiveChargeDefaultsReport? {
        let orderedSessions = sessions.sorted { $0.sessionDate > $1.sessionDate }
        guard !orderedSessions.isEmpty else { return nil }

        let quickPresets = makeQuickPresets(
            sessions: orderedSessions,
            availableHomeProfiles: availableHomeProfiles,
            selectedHomeProfileID: selectedHomeProfileID,
            defaultElectricityTariffPerKWh: defaultElectricityTariffPerKWh
        )

        guard !quickPresets.isEmpty else { return nil }

        return PredictiveChargeDefaultsReport(
            dominantMethod: nil,
            dominantOperator: nil,
            dominantStation: nil,
            timeOfDayHint: nil,
            quickPresets: quickPresets
        )
    }

    private func makeQuickPresets(
        sessions: [ChargingSession],
        availableHomeProfiles: [HomeChargingProfile],
        selectedHomeProfileID: Int,
        defaultElectricityTariffPerKWh: Double?
    ) -> [QuickChargePreset] {
        [
            makeHomePreset(
                sessions: sessions,
                availableHomeProfiles: availableHomeProfiles,
                selectedHomeProfileID: selectedHomeProfileID,
                defaultElectricityTariffPerKWh: defaultElectricityTariffPerKWh
            ),
            makePublicPreset(kind: .publicACFavorite, method: .publicAC, sessions: sessions),
            makePublicPreset(kind: .roadTripDC, method: .publicDC, sessions: sessions)
        ].compactMap { $0 }
    }

    private func makeHomePreset(
        sessions: [ChargingSession],
        availableHomeProfiles: [HomeChargingProfile],
        selectedHomeProfileID: Int,
        defaultElectricityTariffPerKWh: Double?
    ) -> QuickChargePreset? {
        guard let latestHomeSession = sessions.first(where: { $0.chargeMethod == .home }) else {
            return nil
        }

        let profile = availableHomeProfiles.first(where: { $0.id == selectedHomeProfileID }) ?? availableHomeProfiles.first
        let subtitle = profile?.displayName ?? latestHomeSession.stationBrand ?? "Ev şarjı"

        return QuickChargePreset(
            id: QuickChargePresetKind.homeRoutine.rawValue,
            kind: .homeRoutine,
            title: "Ev",
            subtitle: subtitle,
            detail: "Ev şarjı için son kaydı alanlara yerleştirir.",
            prefill: QuickChargePresetPrefill(
                chargeMethod: .home,
                selectedHomeProfileID: profile?.id ?? selectedHomeProfileID,
                stationBrand: latestHomeSession.stationBrand,
                locationName: latestHomeSession.locationName,
                tariffPricePerKWh: latestHomeSession.tlPerKWh ?? profile?.tariffPricePerKWh ?? defaultElectricityTariffPerKWh,
                suggestedSOCStart: sanitizedSOC(latestHomeSession.socStart),
                suggestedSOCEnd: sanitizedSOC(latestHomeSession.socEnd),
                suggestedDurationMinutes: latestHomeSession.durationMin.map(Double.init)
            )
        )
    }

    private func makePublicPreset(
        kind: QuickChargePresetKind,
        method: ChargeMethod,
        sessions: [ChargingSession]
    ) -> QuickChargePreset? {
        guard let latestSession = sessions.first(where: { $0.chargeMethod == method }) else {
            return nil
        }

        let title: String
        let fallbackSubtitle: String
        let detail: String

        switch kind {
        case .publicACFavorite:
            title = "AC"
            fallbackSubtitle = "Son AC kaydı"
            detail = "Son AC kaydındaki alanları hazır doldurur."
        case .roadTripDC:
            title = "DC"
            fallbackSubtitle = "Son DC kaydı"
            detail = "Son DC kaydındaki alanları hazır doldurur."
        case .homeRoutine:
            return nil
        }

        let subtitle = [latestSession.stationBrand, latestSession.locationName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        return QuickChargePreset(
            id: kind.rawValue,
            kind: kind,
            title: title,
            subtitle: subtitle.isEmpty ? fallbackSubtitle : subtitle,
            detail: detail,
            prefill: QuickChargePresetPrefill(
                chargeMethod: method,
                selectedHomeProfileID: nil,
                stationBrand: latestSession.stationBrand,
                locationName: latestSession.locationName,
                tariffPricePerKWh: latestSession.tlPerKWh,
                suggestedSOCStart: sanitizedSOC(latestSession.socStart),
                suggestedSOCEnd: sanitizedSOC(latestSession.socEnd),
                suggestedDurationMinutes: latestSession.durationMin.map(Double.init)
            )
        )
    }

    private func sanitizedSOC(_ value: Double) -> Double? {
        guard value > 0, value <= 100 else { return nil }
        return value
    }
}
