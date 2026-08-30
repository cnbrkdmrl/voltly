import Foundation

public struct RealEVCostSummary: Equatable {
    public let averagePer100Km: Double
    public let bestPer100Km: Double
    public let worstPer100Km: Double
    public let gasolineSavingsPercent: Double?
    public let currencyCode: String
    public let sampleCount: Int
}

@MainActor
public final class RealEVCostViewModel: ObservableObject {
    @Published public private(set) var hasActiveVehicle = false
    @Published public private(set) var summary: RealEVCostSummary?
    @Published public private(set) var fallbackMessage: String?
    @Published public private(set) var errorMessage: String?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func load() {
        do {
            guard let vehicle = try environment.vehicleRepository.fetchActiveVehicle() else {
                resetForNoVehicle()
                return
            }

            hasActiveVehicle = true
            let baseline = try environment.settingsRepository.getFuelBaseline()
            let sessions = try environment.chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            let segmentCosts = buildRealCostSamples(from: sessions)

            guard !segmentCosts.isEmpty else {
                summary = nil
                fallbackMessage = "Gerçek maliyet için art arda en az 2 odometre kaydı ve tutar bilgisi gerekli."
                errorMessage = nil
                return
            }

            let average = segmentCosts.reduce(0, +) / Double(segmentCosts.count)
            let best = segmentCosts.min() ?? average
            let worst = segmentCosts.max() ?? average
            let gasolineSavings = environment.calculateGasolineComparisonUseCase
                .execute(tlPer100km: average, baseline: baseline)?
                .percentCheaper

            summary = RealEVCostSummary(
                averagePer100Km: average,
                bestPer100Km: best,
                worstPer100Km: worst,
                gasolineSavingsPercent: gasolineSavings,
                currencyCode: baseline.currencyCode,
                sampleCount: segmentCosts.count
            )
            fallbackMessage = nil
            errorMessage = nil
        } catch {
            hasActiveVehicle = false
            summary = nil
            fallbackMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func resetForNoVehicle() {
        hasActiveVehicle = false
        summary = nil
        fallbackMessage = "Bu ekran için önce aktif araç seç."
        errorMessage = nil
    }

    private func buildRealCostSamples(from sessions: [ChargingSession]) -> [Double] {
        let sorted = sessions.sorted(by: { $0.sessionDate < $1.sessionDate })
        let odometerSeries = sorted.compactMap { session -> (odometer: Double, totalCost: Double)? in
            guard let odometer = session.odometerKM else { return nil }
            guard session.priceTotal >= 0 else { return nil }
            return (odometer: odometer, totalCost: session.priceTotal)
        }

        guard odometerSeries.count >= 2 else { return [] }

        var samples: [Double] = []
        samples.reserveCapacity(max(0, odometerSeries.count - 1))

        for index in 1..<odometerSeries.count {
            let previous = odometerSeries[index - 1]
            let current = odometerSeries[index]
            let distance = current.odometer - previous.odometer
            guard distance > 0 else { continue }

            let costPer100Km = (current.totalCost / distance) * 100
            if costPer100Km.isFinite {
                samples.append(costPer100Km)
            }
        }

        return samples
    }
}
