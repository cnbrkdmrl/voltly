import Foundation

public struct CreateVehicleUseCase {
    private let repository: VehicleRepository

    public init(repository: VehicleRepository) {
        self.repository = repository
    }

    public func execute(_ vehicle: Vehicle) throws {
        try repository.upsert(vehicle: vehicle)
        let existing = try repository.fetchVehicles()
        if existing.count == 1 {
            try repository.setActiveVehicle(id: vehicle.id)
        }
    }
}

public struct UpdateVehicleUseCase {
    private let repository: VehicleRepository

    public init(repository: VehicleRepository) {
        self.repository = repository
    }

    public func execute(_ vehicle: Vehicle) throws {
        try repository.upsert(vehicle: vehicle)
    }
}

public enum DeleteVehicleError: Error, Equatable {
    case hasSessions
}

public struct DeleteVehicleUseCase {
    private let vehicleRepository: VehicleRepository
    private let sessionRepository: ChargingSessionRepository

    public init(vehicleRepository: VehicleRepository, sessionRepository: ChargingSessionRepository) {
        self.vehicleRepository = vehicleRepository
        self.sessionRepository = sessionRepository
    }

    public func execute(vehicleID: UUID) throws {
        let sessionCount = try sessionRepository.count(vehicleID: vehicleID)
        guard sessionCount == 0 else { throw DeleteVehicleError.hasSessions }
        try vehicleRepository.delete(vehicleID: vehicleID)
    }
}

public struct SetActiveVehicleUseCase {
    private let repository: VehicleRepository

    public init(repository: VehicleRepository) {
        self.repository = repository
    }

    public func execute(id: UUID) throws {
        try repository.setActiveVehicle(id: id)
    }
}
