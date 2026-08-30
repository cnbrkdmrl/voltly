import Foundation

public struct BackupValidator {
    public let supportedSchemaVersion: Int

    public init(supportedSchemaVersion: Int = AppSchemaVersion.current.rawValue) {
        self.supportedSchemaVersion = supportedSchemaVersion
    }

    public func decodeAndValidate(from data: Data, decoder: JSONDecoder = JSONBackupBuilder.makeDecoder()) throws -> BackupArchiveDTO {
        let archive: BackupArchiveDTO
        do {
            archive = try decoder.decode(BackupArchiveDTO.self, from: data)
        } catch {
            throw BackupValidationError.corruptedJSON
        }

        try validate(archive)
        return archive
    }

    public func validate(_ archive: BackupArchiveDTO) throws {
        guard archive.schemaVersion == supportedSchemaVersion else {
            throw BackupValidationError.unsupportedSchemaVersion(
                expected: supportedSchemaVersion,
                found: archive.schemaVersion
            )
        }

        guard !archive.appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BackupValidationError.invalidArchive(reason: "appVersion alani bos olamaz")
        }
    }

    public func duplicateIdentifierWarnings(in archive: BackupArchiveDTO) -> [String] {
        var warnings: [String] = []

        warnings.append(contentsOf: duplicateWarnings(in: archive.vehicles.map(\.id), label: "vehicles"))
        warnings.append(contentsOf: duplicateWarnings(in: archive.chargingSessions.map(\.id), label: "chargingSessions"))
        warnings.append(contentsOf: duplicateWarnings(in: archive.tariffPresets.map(\.id), label: "tariffPresets"))

        return warnings
    }

    private func duplicateWarnings(in identifiers: [UUID], label: String) -> [String] {
        var seen = Set<UUID>()
        var duplicateCount = 0

        for identifier in identifiers {
            if seen.contains(identifier) {
                duplicateCount += 1
            } else {
                seen.insert(identifier)
            }
        }

        guard duplicateCount > 0 else {
            return []
        }

        return ["\(label) alaninda \(duplicateCount) adet tekrarlanan kayit bulundu. En guncel olan kayitlar kullanilacak."]
    }
}
