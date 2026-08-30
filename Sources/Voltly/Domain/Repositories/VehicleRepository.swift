import Foundation

public protocol VehicleRepository {
    func fetchVehicles() throws -> [Vehicle]
    func fetchActiveVehicle() throws -> Vehicle?
    func upsert(vehicle: Vehicle) throws
    func delete(vehicleID: UUID) throws
    func setActiveVehicle(id: UUID) throws
}
