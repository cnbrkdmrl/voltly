import Foundation

public struct LogChargingSessionUseCase {
    private let repository: ChargingSessionRepository
    private let chargeRecordService: ChargeRecordService?

    public init(
        repository: ChargingSessionRepository,
        chargeRecordService: ChargeRecordService? = nil
    ) {
        self.repository = repository
        self.chargeRecordService = chargeRecordService
    }

    @discardableResult
    public func execute(_ session: ChargingSession) throws -> ChargeMetricsRealtimeUpdate? {
        if let chargeRecordService {
            return try chargeRecordService.save(session)
        }

        try repository.save(session: session)
        return nil
    }
}

public struct ListChargingSessionsUseCase {
    private let repository: ChargingSessionRepository

    public init(repository: ChargingSessionRepository) {
        self.repository = repository
    }

    public func execute(vehicleID: UUID? = nil) throws -> [ChargingSession] {
        try repository.fetchAll(vehicleID: vehicleID)
    }
}

public struct DeleteChargingSessionUseCase {
    private let repository: ChargingSessionRepository
    private let chargeRecordService: ChargeRecordService?

    public init(
        repository: ChargingSessionRepository,
        chargeRecordService: ChargeRecordService? = nil
    ) {
        self.repository = repository
        self.chargeRecordService = chargeRecordService
    }

    @discardableResult
    public func execute(id: UUID) throws -> ChargeMetricsRealtimeUpdate? {
        if let chargeRecordService {
            return try chargeRecordService.delete(sessionID: id)
        }

        try repository.delete(sessionID: id)
        return nil
    }
}
