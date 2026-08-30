import Foundation

public struct FileExportManager {
    private let fileManager: FileManager
    private let baseDirectoryProvider: () -> URL

    public init(
        fileManager: FileManager = .default,
        baseDirectoryProvider: @escaping () -> URL = { FileManager.default.temporaryDirectory }
    ) {
        self.fileManager = fileManager
        self.baseDirectoryProvider = baseDirectoryProvider
    }

    public func makeFileURL(
        for descriptor: ExportFileDescriptor,
        in directoryURL: URL? = nil
    ) throws -> URL {
        let rootDirectory = directoryURL ?? baseDirectoryProvider()
        let exportDirectory = rootDirectory.appendingPathComponent(descriptor.directoryName, isDirectory: true)
        try ensureDirectoryExists(at: exportDirectory)
        return exportDirectory.appendingPathComponent(descriptor.fileName, isDirectory: false)
    }

    public func write(_ data: Data, to fileURL: URL) throws {
        try data.write(to: fileURL, options: .atomic)
    }

    public func write(_ text: String, to fileURL: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = text.data(using: encoding) else {
            throw BackupValidationError.invalidArchive(reason: "Yazi belirtilen kodlama ile dosyaya donusturulemedi")
        }
        try write(data, to: fileURL)
    }

    private func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw BackupValidationError.invalidArchive(reason: "Disa aktarma yolu bir klasor degil")
            }
            return
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
