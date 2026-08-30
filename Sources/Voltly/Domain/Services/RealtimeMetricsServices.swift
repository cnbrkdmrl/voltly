import Foundation

public final class MetricsEventBus {
    public typealias Handler = (ChargeRecordEvent) throws -> ChargeMetricsRealtimeUpdate?

    private var handlers: [UUID: Handler] = [:]

    public init() {}

    @discardableResult
    public func register(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        handlers[id] = handler
        return id
    }

    public func unregister(_ id: UUID) {
        handlers.removeValue(forKey: id)
    }

    public func publish(_ event: ChargeRecordEvent) throws -> ChargeMetricsRealtimeUpdate? {
        var latestUpdate: ChargeMetricsRealtimeUpdate?
        for handler in handlers.values {
            if let update = try handler(event) {
                latestUpdate = update
            }
        }
        return latestUpdate
    }
}

public struct GasolineComparisonService {
    public init() {}

    public func makeComparison(
        avgTRY100Km: Double?,
        baseline: FuelBaselineSettings
    ) -> (gasolineTRY100Km: Double?, savingTRY100Km: Double?, savingPercent: Double?) {
        let gasolineTRY100Km = baseline.fuelPricePerLiter * baseline.iceConsumptionLPer100Km
        guard gasolineTRY100Km > 0 else {
            return (nil, nil, nil)
        }

        guard let avgTRY100Km else {
            return (gasolineTRY100Km, nil, nil)
        }

        let savingTRY100Km = gasolineTRY100Km - avgTRY100Km
        let savingPercent = (savingTRY100Km / gasolineTRY100Km) * 100
        return (gasolineTRY100Km, savingTRY100Km, savingPercent)
    }
}

public struct BlockSelectionService {
    private enum Constants {
        static let minimumEstimatedDistanceKM = 500.0
        static let minimumRealDistanceKM = 1_000.0
        static let maximumDistanceKM = 3_000.0
    }

    public struct SelectionCandidate: Equatable {
        public let startIndex: Int
        public let endIndex: Int
        public let startSession: ChargingSession
        public let endSession: ChargingSession
        public let blockSessions: [ChargingSession]
        public let deltaKM: Double

        public var confidenceType: ConsumptionBlockConfidenceType {
            deltaKM >= Constants.minimumRealDistanceKM ? .real : .estimated
        }
    }

    private let validation: CalculationValidationService

    public init(validation: CalculationValidationService = .init()) {
        self.validation = validation
    }

    public func selectBestBlock(
        endingAt endIndex: Int,
        in sessions: [ChargingSession]
    ) -> SelectionCandidate? {
        guard sessions.indices.contains(endIndex) else { return nil }
        let endSession = sessions[endIndex]
        guard let endKM = endSession.odometerKM else { return nil }

        let candidates = sessions[..<endIndex].enumerated().compactMap { pair -> SelectionCandidate? in
            let index = pair.offset
            let startSession = pair.element
            guard let startKM = startSession.odometerKM else { return nil }

            let deltaKM = endKM - startKM
            let interval = endSession.sessionDate.timeIntervalSince(startSession.sessionDate)
            guard validation.isPlausibleDistance(distance: deltaKM, interval: interval),
                  deltaKM >= Constants.minimumEstimatedDistanceKM,
                  deltaKM < Constants.maximumDistanceKM else {
                return nil
            }

            let blockSessions = Array(sessions[index...endIndex])
            return SelectionCandidate(
                startIndex: index,
                endIndex: endIndex,
                startSession: startSession,
                endSession: endSession,
                blockSessions: blockSessions,
                deltaKM: deltaKM
            )
        }

        if let realCandidate = candidates
            .filter({ $0.deltaKM >= Constants.minimumRealDistanceKM })
            .min(by: { $0.deltaKM < $1.deltaKM }) {
            return realCandidate
        }

        return candidates.min(by: { $0.deltaKM < $1.deltaKM })
    }
}

public struct ConsumptionCalculationService {
    private let validation: CalculationValidationService

    public init(validation: CalculationValidationService = .init()) {
        self.validation = validation
    }

    public func makeBlock(
        vehicle: Vehicle,
        candidate: BlockSelectionService.SelectionCandidate?,
        fallbackSession: ChargingSession,
        fallbackVersion: Int = 1
    ) -> ConsumptionBlock? {
        if let candidate {
            let totalKWh = candidate.blockSessions.reduce(0.0) { $0 + max($1.energyKWh ?? 0, 0) }
            let totalCost = candidate.blockSessions.reduce(0.0) { $0 + max($1.priceTotal, 0) }
            guard totalKWh > 0 else { return nil }

            let kWhPer100Km = (totalKWh / candidate.deltaKM) * 100
            let tryPer100Km = (totalCost / candidate.deltaKM) * 100

            if validation.isValidConsumption(kWhPer100Km) {
                return ConsumptionBlock(
                    vehicleID: fallbackSession.vehicleID,
                    startRecordID: candidate.startSession.id,
                    endRecordID: candidate.endSession.id,
                    startKM: candidate.startSession.odometerKM,
                    endKM: candidate.endSession.odometerKM,
                    deltaKM: candidate.deltaKM,
                    totalKWh: totalKWh,
                    totalCostTRY: totalCost,
                    kWhPer100Km: kWhPer100Km,
                    tryPer100Km: tryPer100Km,
                    confidenceType: candidate.confidenceType,
                    calculationBasis: candidate.confidenceType.basisLabel,
                    isDirty: false,
                    version: fallbackVersion,
                    updatedAt: .now,
                    startDate: candidate.startSession.sessionDate,
                    endDate: candidate.endSession.sessionDate
                )
            }

            return makeFactoryFallback(
                vehicle: vehicle,
                sessions: candidate.blockSessions,
                fallbackSession: fallbackSession,
                version: fallbackVersion
            )
        }

        return makeFactoryFallback(
            vehicle: vehicle,
            sessions: [fallbackSession],
            fallbackSession: fallbackSession,
            version: fallbackVersion
        )
    }

    private func makeFactoryFallback(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        fallbackSession: ChargingSession,
        version: Int
    ) -> ConsumptionBlock? {
        guard let factoryConsumption = vehicle.factoryConsumptionKWh100km,
              factoryConsumption > 0 else {
            return nil
        }

        let totalKWh = sessions.reduce(0.0) { $0 + max($1.energyKWh ?? 0, 0) }
        let totalCost = sessions.reduce(0.0) { $0 + max($1.priceTotal, 0) }
        guard totalKWh > 0 else { return nil }

        let estimatedDistance = (totalKWh / factoryConsumption) * 100
        guard estimatedDistance > 0 else { return nil }

        let tryPer100Km = (totalCost / estimatedDistance) * 100
        let startSession = sessions.first ?? fallbackSession
        let endSession = sessions.last ?? fallbackSession

        return ConsumptionBlock(
            vehicleID: fallbackSession.vehicleID,
            startRecordID: startSession.id,
            endRecordID: endSession.id,
            startKM: startSession.odometerKM,
            endKM: endSession.odometerKM,
            deltaKM: estimatedDistance,
            totalKWh: totalKWh,
            totalCostTRY: totalCost,
            kWhPer100Km: factoryConsumption,
            tryPer100Km: tryPer100Km,
            confidenceType: .factory,
            calculationBasis: ConsumptionBlockConfidenceType.factory.basisLabel,
            isDirty: false,
            version: version,
            updatedAt: .now,
            startDate: startSession.sessionDate,
            endDate: endSession.sessionDate
        )
    }
}

public struct MetricsSnapshotService {
    private let gasolineComparisonService: GasolineComparisonService

    public init(gasolineComparisonService: GasolineComparisonService = .init()) {
        self.gasolineComparisonService = gasolineComparisonService
    }

    public func buildSnapshots(
        vehicleID: UUID,
        blocks: [ConsumptionBlock],
        baseline: FuelBaselineSettings,
        referenceDate: Date = .now
    ) -> [VehicleMetricSnapshot] {
        VehicleMetricSnapshotPeriod.allCases.map { period in
            let periodBlocks = blocks.filter { block in
                switch period {
                case .last30Days:
                    return block.endDate >= Calendar.current.date(byAdding: .day, value: -30, to: referenceDate) ?? .distantPast
                case .last365Days:
                    return block.endDate >= Calendar.current.date(byAdding: .day, value: -365, to: referenceDate) ?? .distantPast
                case .allTime:
                    return true
                }
            }

            let totalKWh = periodBlocks.reduce(0.0) { $0 + $1.totalKWh }
            let totalCost = periodBlocks.reduce(0.0) { $0 + $1.totalCostTRY }
            let totalDistance = periodBlocks.reduce(0.0) { $0 + $1.deltaKM }

            let avgKWh100Km = totalDistance > 0 ? (totalKWh / totalDistance) * 100 : nil
            let avgTRY100Km = totalDistance > 0 ? (totalCost / totalDistance) * 100 : nil
            let dominantConfidence = dominantConfidenceType(from: periodBlocks)
            let gasolineComparison = gasolineComparisonService.makeComparison(
                avgTRY100Km: avgTRY100Km,
                baseline: baseline
            )

            return VehicleMetricSnapshot(
                vehicleID: vehicleID,
                period: period,
                avgKWh100Km: avgKWh100Km,
                avgTRY100Km: avgTRY100Km,
                gasolineTRY100Km: gasolineComparison.gasolineTRY100Km,
                savingTRY100Km: gasolineComparison.savingTRY100Km,
                savingPercent: gasolineComparison.savingPercent,
                basisLabel: dominantConfidence.basisLabel
            )
        }
    }

    private func dominantConfidenceType(from blocks: [ConsumptionBlock]) -> ConsumptionBlockConfidenceType {
        guard !blocks.isEmpty else { return .factory }
        let grouped = Dictionary(grouping: blocks, by: \.confidenceType)
        return grouped.max { lhs, rhs in
            lhs.value.reduce(0.0) { $0 + $1.deltaKM } < rhs.value.reduce(0.0) { $0 + $1.deltaKM }
        }?.key ?? .factory
    }
}

public final class RealtimeMetricsProjectionService {
    private let sessionRepository: any ChargingSessionRepository
    private let vehicleRepository: any VehicleRepository
    private let settingsRepository: any SettingsRepository
    private let blockRepository: any ConsumptionBlockRepository
    private let snapshotRepository: any VehicleMetricSnapshotRepository
    private let dashboardCacheService: any DashboardCacheService
    private let blockSelectionService: BlockSelectionService
    private let consumptionCalculationService: ConsumptionCalculationService
    private let metricsSnapshotService: MetricsSnapshotService

    public init(
        sessionRepository: any ChargingSessionRepository,
        vehicleRepository: any VehicleRepository,
        settingsRepository: any SettingsRepository,
        blockRepository: any ConsumptionBlockRepository,
        snapshotRepository: any VehicleMetricSnapshotRepository,
        dashboardCacheService: any DashboardCacheService,
        blockSelectionService: BlockSelectionService = .init(),
        consumptionCalculationService: ConsumptionCalculationService = .init(),
        metricsSnapshotService: MetricsSnapshotService = .init()
    ) {
        self.sessionRepository = sessionRepository
        self.vehicleRepository = vehicleRepository
        self.settingsRepository = settingsRepository
        self.blockRepository = blockRepository
        self.snapshotRepository = snapshotRepository
        self.dashboardCacheService = dashboardCacheService
        self.blockSelectionService = blockSelectionService
        self.consumptionCalculationService = consumptionCalculationService
        self.metricsSnapshotService = metricsSnapshotService
    }

    public func handle(event: ChargeRecordEvent) throws -> ChargeMetricsRealtimeUpdate? {
        let vehicles = try vehicleRepository.fetchVehicles()
        guard let vehicle = vehicles.first(where: { $0.id == event.vehicleID }) else { return nil }
        let sessions = try sessionRepository.fetchAll(vehicleID: event.vehicleID)
            .sorted { $0.sessionDate < $1.sessionDate }
        let baseline = try settingsRepository.getFuelBaseline()

        let existingBlocks = try blockRepository.fetchActive(vehicleID: event.vehicleID)
        let blocks = try rebuildBlocks(
            for: vehicle,
            sessions: sessions,
            event: event,
            existingBlocks: existingBlocks
        )
        try blockRepository.replaceActive(vehicleID: event.vehicleID, blocks: blocks)

        let snapshots = metricsSnapshotService.buildSnapshots(
            vehicleID: event.vehicleID,
            blocks: blocks,
            baseline: baseline
        )
        try snapshotRepository.replace(vehicleID: event.vehicleID, snapshots: snapshots)
        try dashboardCacheService.invalidate(vehicleID: event.vehicleID)

        let latestBlock = blocks.last { $0.endRecordID == event.sessionID } ?? blocks.last
        let update = ChargeMetricsRealtimeUpdate(
            vehicleID: event.vehicleID,
            latestBlock: latestBlock,
            snapshots: Dictionary(uniqueKeysWithValues: snapshots.map { ($0.period, $0) }),
            invalidatedDashboard: true
        )
        try dashboardCacheService.cache(update: update)
        return update
    }

    private func rebuildBlocks(
        for vehicle: Vehicle,
        sessions: [ChargingSession],
        event: ChargeRecordEvent,
        existingBlocks: [ConsumptionBlock]
    ) throws -> [ConsumptionBlock] {
        guard !sessions.isEmpty else { return [] }

        if event.type == .created,
           event.wasLatestByDate {
            if let latestIndex = sessions.lastIndex(where: { $0.id == event.sessionID }) {
                let latestCandidate = blockSelectionService.selectBestBlock(endingAt: latestIndex, in: sessions)
                let latestStartDate = latestCandidate?.startSession.sessionDate ?? sessions[latestIndex].sessionDate
                let keptBlocks = existingBlocks.filter { $0.endDate < latestStartDate }
                let tailSessions = sessions.filter { $0.sessionDate >= (keptBlocks.last?.endDate ?? .distantPast) }
                let rebuiltTail = greedyRebuildBlocks(for: vehicle, sessions: tailSessions)
                return keptBlocks + rebuiltTail
            }
        }

        let rebuildStartDate = earliestAffectedStartDate(
            existingBlocks: existingBlocks,
            event: event,
            sessions: sessions
        )
        let keptBlocks = existingBlocks.filter { $0.endDate < rebuildStartDate }
        let tailSessions = sessions.filter { $0.sessionDate >= rebuildStartDate }
        let rebuiltTail = greedyRebuildBlocks(for: vehicle, sessions: tailSessions)
        return keptBlocks + rebuiltTail
    }

    private func earliestAffectedStartDate(
        existingBlocks: [ConsumptionBlock],
        event: ChargeRecordEvent,
        sessions: [ChargingSession]
    ) -> Date {
        if let affectedBlock = existingBlocks.first(where: { block in
            block.startDate <= event.sessionDate && block.endDate >= event.sessionDate
        }) {
            return affectedBlock.startDate
        }

        if let nextBlock = existingBlocks.first(where: { $0.endDate >= event.sessionDate }) {
            return nextBlock.startDate
        }

        return sessions.first(where: { $0.sessionDate >= event.sessionDate })?.sessionDate
            ?? event.sessionDate
    }

    private func greedyRebuildBlocks(
        for vehicle: Vehicle,
        sessions: [ChargingSession]
    ) -> [ConsumptionBlock] {
        let validSessions = sessions
            .filter { ($0.energyKWh ?? 0) > 0 }
            .sorted { $0.sessionDate < $1.sessionDate }

        guard !validSessions.isEmpty else { return [] }

        var blocks: [ConsumptionBlock] = []
        var endIndex = validSessions.count - 1
        var version = 1

        while endIndex >= 0 {
            let anchor = validSessions[endIndex]
            let candidate = blockSelectionService.selectBestBlock(endingAt: endIndex, in: validSessions)
            let block = consumptionCalculationService.makeBlock(
                vehicle: vehicle,
                candidate: candidate,
                fallbackSession: anchor,
                fallbackVersion: version
            )
            if let block {
                blocks.insert(block, at: 0)
            }

            if let candidate {
                endIndex = candidate.startIndex - 1
            } else {
                endIndex -= 1
            }
            version += 1
        }

        return blocks
    }
}

public final class ChargeRecordService {
    private let sessionRepository: any ChargingSessionRepository
    private let metricsEventBus: MetricsEventBus

    public init(
        sessionRepository: any ChargingSessionRepository,
        metricsEventBus: MetricsEventBus
    ) {
        self.sessionRepository = sessionRepository
        self.metricsEventBus = metricsEventBus
    }

    public func save(_ session: ChargingSession) throws -> ChargeMetricsRealtimeUpdate? {
        let existingSessions = try sessionRepository.fetchAll(vehicleID: session.vehicleID)
        let existing = existingSessions.first(where: { $0.id == session.id })

        try sessionRepository.save(session: session)

        let refreshed = try sessionRepository.fetchAll(vehicleID: session.vehicleID)
        let latestByDateID = refreshed.max(by: { $0.sessionDate < $1.sessionDate })?.id
        let event = ChargeRecordEvent(
            type: existing == nil ? .created : .updated,
            sessionID: session.id,
            vehicleID: session.vehicleID,
            sessionDate: session.sessionDate,
            wasLatestByDate: latestByDateID == session.id
        )
        return try metricsEventBus.publish(event)
    }

    public func delete(sessionID: UUID) throws -> ChargeMetricsRealtimeUpdate? {
        let allSessions = try sessionRepository.fetchAll(vehicleID: nil)
        guard let existing = allSessions.first(where: { $0.id == sessionID }) else {
            return nil
        }

        try sessionRepository.delete(sessionID: sessionID)
        let latestByDateID = try sessionRepository.fetchAll(vehicleID: existing.vehicleID)
            .max(by: { $0.sessionDate < $1.sessionDate })?.id
        let event = ChargeRecordEvent(
            type: .deleted,
            sessionID: existing.id,
            vehicleID: existing.vehicleID,
            sessionDate: existing.sessionDate,
            wasLatestByDate: latestByDateID == existing.id
        )
        return try metricsEventBus.publish(event)
    }
}
