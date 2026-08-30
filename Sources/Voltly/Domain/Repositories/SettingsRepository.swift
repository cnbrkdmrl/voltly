import Foundation

public protocol SettingsRepository {
    func getFuelBaseline() throws -> FuelBaselineSettings
    func saveFuelBaseline(_ settings: FuelBaselineSettings) throws
}
