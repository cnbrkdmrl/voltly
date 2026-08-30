import Foundation

public protocol SessionsCSVExportServiceProtocol {
    func exportChargingSessionsCSV(to directoryURL: URL?) throws -> URL
}
