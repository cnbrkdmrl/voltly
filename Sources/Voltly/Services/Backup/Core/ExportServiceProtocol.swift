import Foundation

public protocol ExportServiceProtocol {
    func exportArchive(to directoryURL: URL?) throws -> URL
}
