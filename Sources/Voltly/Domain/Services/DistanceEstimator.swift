import Foundation

public struct DistanceEstimationInput {
    public struct SessionSample: Equatable, Sendable {
        public let id: UUID
        public let date: Date
        public let energyKWh: Double
        public let effectiveCost: Double
        public let odometerKM: Double?
        public let isSuspicious: Bool

        public init(
            id: UUID,
            date: Date,
            energyKWh: Double,
            effectiveCost: Double,
            odometerKM: Double?,
            isSuspicious: Bool
        ) {
            self.id = id
            self.date = date
            self.energyKWh = energyKWh
            self.effectiveCost = effectiveCost
            self.odometerKM = odometerKM
            self.isSuspicious = isSuspicious
        }
    }

    public let sessions: [SessionSample]
    public let referenceConsumptionKWh100Km: Double
    public let referenceSource: ConsumptionReferenceSource

    public init(
        sessions: [SessionSample],
        referenceConsumptionKWh100Km: Double,
        referenceSource: ConsumptionReferenceSource
    ) {
        self.sessions = sessions
        self.referenceConsumptionKWh100Km = referenceConsumptionKWh100Km
        self.referenceSource = referenceSource
    }
}

public struct OdometerDistanceBlock: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let distanceKm: Double
    public let totalEnergyKWh: Double
    public let totalCost: Double
    public let sessionCount: Int

    public init(
        startDate: Date,
        endDate: Date,
        distanceKm: Double,
        totalEnergyKWh: Double,
        totalCost: Double,
        sessionCount: Int
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.distanceKm = distanceKm
        self.totalEnergyKWh = totalEnergyKWh
        self.totalCost = totalCost
        self.sessionCount = sessionCount
    }
}

public struct DistanceEstimationResult: Equatable, Sendable {
    public let estimatedDistanceKm: Double
    public let reliableDistanceKm: Double
    public let mode: DistanceCalculationMode
    public let odometerPointCount: Int
    public let validTransitionCount: Int
    public let invalidTransitionReasons: [String]
    public let energyEstimatedPortionKWh: Double
    public let referenceSource: ConsumptionReferenceSource
    public let selectedBlock: OdometerDistanceBlock?

    public init(
        estimatedDistanceKm: Double,
        reliableDistanceKm: Double,
        mode: DistanceCalculationMode,
        odometerPointCount: Int,
        validTransitionCount: Int,
        invalidTransitionReasons: [String],
        energyEstimatedPortionKWh: Double,
        referenceSource: ConsumptionReferenceSource,
        selectedBlock: OdometerDistanceBlock? = nil
    ) {
        self.estimatedDistanceKm = estimatedDistanceKm
        self.reliableDistanceKm = reliableDistanceKm
        self.mode = mode
        self.odometerPointCount = odometerPointCount
        self.validTransitionCount = validTransitionCount
        self.invalidTransitionReasons = invalidTransitionReasons
        self.energyEstimatedPortionKWh = energyEstimatedPortionKWh
        self.referenceSource = referenceSource
        self.selectedBlock = selectedBlock
    }
}

public struct DistanceEstimator {
    private enum BlockSelection {
        static let minimumEstimatedDistanceKM = 500.0
        static let minimumRealDistanceKM = 1_000.0
        static let maximumBlockDistanceKM = 3_000.0
    }

    private let validation: CalculationValidationService

    public init(validation: CalculationValidationService = .init()) {
        self.validation = validation
    }

    public func estimate(input: DistanceEstimationInput) -> DistanceEstimationResult {
        let sorted = input.sessions.sorted { $0.date < $1.date }
        let odometerSamples = sorted.compactMap { sample -> DistanceEstimationInput.SessionSample? in
            guard sample.odometerKM != nil else { return nil }
            return sample
        }

        var validDistanceKM: Double = 0
        var validTransitionCount = 0
        var invalidReasons: [String] = []
        var sessionsUsedByOdometer: Set<UUID> = []

        if let selectedBlock = selectClosestValidBlock(from: sorted, odometerSamples: odometerSamples) {
            return DistanceEstimationResult(
                estimatedDistanceKm: selectedBlock.distanceKm,
                reliableDistanceKm: selectedBlock.distanceKm,
                mode: .odometer,
                odometerPointCount: odometerSamples.count,
                validTransitionCount: 1,
                invalidTransitionReasons: invalidReasons,
                energyEstimatedPortionKWh: 0,
                referenceSource: input.referenceSource,
                selectedBlock: selectedBlock
            )
        }

        if odometerSamples.count >= 2 {
            for index in 1..<odometerSamples.count {
                let previous = odometerSamples[index - 1]
                let current = odometerSamples[index]
                guard let previousOdometer = previous.odometerKM,
                      let currentOdometer = current.odometerKM else {
                    continue
                }

                let distance = currentOdometer - previousOdometer
                let interval = current.date.timeIntervalSince(previous.date)
                guard validation.isPlausibleDistance(distance: distance, interval: interval) else {
                    invalidReasons.append("odometer_transition_invalid")
                    continue
                }

                validDistanceKM += distance
                validTransitionCount += 1
                sessionsUsedByOdometer.insert(previous.id)
                sessionsUsedByOdometer.insert(current.id)
            }
        }

        let weightedEnergyOutsideOdometer = sorted.reduce(0.0) { total, sample in
            guard !sessionsUsedByOdometer.contains(sample.id) else { return total }
            return total + sample.energyKWh
        }
        let estimatedDistanceFromEnergy = validation.safePer100(
            numerator: weightedEnergyOutsideOdometer,
            denominator: input.referenceConsumptionKWh100Km
        ) ?? 0

        if validTransitionCount >= 1, validDistanceKM > 0 {
            if estimatedDistanceFromEnergy > 0 {
                return DistanceEstimationResult(
                    estimatedDistanceKm: validDistanceKM + estimatedDistanceFromEnergy,
                    reliableDistanceKm: validDistanceKM,
                    mode: .hybrid,
                    odometerPointCount: odometerSamples.count,
                    validTransitionCount: validTransitionCount,
                    invalidTransitionReasons: invalidReasons,
                    energyEstimatedPortionKWh: weightedEnergyOutsideOdometer,
                    referenceSource: input.referenceSource
                )
            }

            return DistanceEstimationResult(
                estimatedDistanceKm: validDistanceKM,
                reliableDistanceKm: validDistanceKM,
                mode: .odometer,
                odometerPointCount: odometerSamples.count,
                validTransitionCount: validTransitionCount,
                invalidTransitionReasons: invalidReasons,
                energyEstimatedPortionKWh: 0,
                referenceSource: input.referenceSource
            )
        }

        let weightedTotalEnergy = sorted.reduce(0.0) { total, sample in
            total + sample.energyKWh
        }
        let estimatedDistance = validation.safePer100(
            numerator: weightedTotalEnergy,
            denominator: input.referenceConsumptionKWh100Km
        ) ?? 0

        return DistanceEstimationResult(
            estimatedDistanceKm: estimatedDistance,
            reliableDistanceKm: 0,
            mode: .energyEstimated,
            odometerPointCount: odometerSamples.count,
            validTransitionCount: validTransitionCount,
            invalidTransitionReasons: invalidReasons,
            energyEstimatedPortionKWh: weightedTotalEnergy,
            referenceSource: input.referenceSource
        )
    }

    private func selectClosestValidBlock(
        from sorted: [DistanceEstimationInput.SessionSample],
        odometerSamples: [DistanceEstimationInput.SessionSample]
    ) -> OdometerDistanceBlock? {
        guard let current = odometerSamples.last,
              let currentOdometer = current.odometerKM else {
            return nil
        }

        let candidates = odometerSamples.dropLast().compactMap { past -> OdometerDistanceBlock? in
            guard let pastOdometer = past.odometerKM else { return nil }

            let deltaKM = currentOdometer - pastOdometer
            let interval = current.date.timeIntervalSince(past.date)
            guard validation.isPlausibleDistance(distance: deltaKM, interval: interval) else {
                return nil
            }
            guard deltaKM >= BlockSelection.minimumEstimatedDistanceKM,
                  deltaKM < BlockSelection.maximumBlockDistanceKM else {
                return nil
            }

            let blockSessions = sorted.filter { sample in
                sample.date >= past.date && sample.date <= current.date
            }
            guard !blockSessions.isEmpty else { return nil }

            let totalEnergyKWh = blockSessions.reduce(0.0) { $0 + $1.energyKWh }
            let totalCost = blockSessions.reduce(0.0) { $0 + $1.effectiveCost }

            return OdometerDistanceBlock(
                startDate: past.date,
                endDate: current.date,
                distanceKm: deltaKM,
                totalEnergyKWh: totalEnergyKWh,
                totalCost: totalCost,
                sessionCount: blockSessions.count
            )
        }

        let realCandidate = candidates
            .filter { $0.distanceKm >= BlockSelection.minimumRealDistanceKM }
            .min { $0.distanceKm < $1.distanceKm }
        if let realCandidate {
            return realCandidate
        }

        return candidates.min { $0.distanceKm < $1.distanceKm }
    }
}
