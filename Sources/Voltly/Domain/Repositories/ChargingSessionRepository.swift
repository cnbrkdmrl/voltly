import Foundation

public protocol ChargingSessionRepository {
    func save(session: ChargingSession) throws
    func delete(sessionID: UUID) throws
    func fetchAll(vehicleID: UUID?) throws -> [ChargingSession]
    func fetchRecent(vehicleID: UUID?, limit: Int) throws -> [ChargingSession]
    func fetchInRange(vehicleID: UUID?, from: Date, to: Date) throws -> [ChargingSession]
    func count(vehicleID: UUID) throws -> Int
}
