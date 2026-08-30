import Foundation

public enum MigrationRegistryValidationError: LocalizedError, Equatable {
    case duplicateID(String)
    case duplicateFromVersion(Int)
    case invalidVersionRange(id: String, fromVersion: Int, toVersion: Int)
    case emptyID
    case emptyName(id: String)
    case missingStep(fromVersion: Int, targetVersion: Int)
    case downgradeNotSupported(current: Int, target: Int)

    public var errorDescription: String? {
        switch self {
        case .duplicateID(let id):
            return "Migration kaydinda tekrar eden id bulundu: \(id)."
        case .duplicateFromVersion(let version):
            return "Migration kaydinda ayni fromVersion degeri tekrar ediyor: \(version)."
        case .invalidVersionRange(let id, let fromVersion, let toVersion):
            return "Migration sürüm aralığı geçersiz (\(id)): \(fromVersion) -> \(toVersion)."
        case .emptyID:
            return "Migration id alani bos olamaz."
        case .emptyName(let id):
            return "Migration name alani bos olamaz (\(id))."
        case .missingStep(let fromVersion, let targetVersion):
            return "Migration zinciri eksik. \(fromVersion) sürümünden \(targetVersion) sürümüne adım bulunamadı."
        case .downgradeNotSupported(let current, let target):
            return "Schema downgrade desteklenmiyor. Mevcut: \(current), hedef: \(target)."
        }
    }
}

public struct MigrationRegistryWarning: Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct MigrationValidationReport: Equatable, Sendable {
    public let warnings: [MigrationRegistryWarning]

    public init(warnings: [MigrationRegistryWarning]) {
        self.warnings = warnings
    }
}

public struct MigrationRegistry {
    private let migrationsByFromVersion: [Int: any Migration]
    private let orderWarnings: [MigrationRegistryWarning]

    public init(migrations: [any Migration]) throws {
        var map: [Int: any Migration] = [:]
        var ids = Set<String>()

        for migration in migrations {
            let normalizedID = migration.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty else {
                throw MigrationRegistryValidationError.emptyID
            }

            let normalizedName = migration.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else {
                throw MigrationRegistryValidationError.emptyName(id: migration.id)
            }

            guard migration.toVersion > migration.fromVersion else {
                throw MigrationRegistryValidationError.invalidVersionRange(
                    id: migration.id,
                    fromVersion: migration.fromVersion,
                    toVersion: migration.toVersion
                )
            }

            guard ids.insert(migration.id).inserted else {
                throw MigrationRegistryValidationError.duplicateID(migration.id)
            }

            guard map[migration.fromVersion] == nil else {
                throw MigrationRegistryValidationError.duplicateFromVersion(migration.fromVersion)
            }

            map[migration.fromVersion] = migration
        }

        migrationsByFromVersion = map
        orderWarnings = Self.detectOrderWarnings(migrations: migrations)
    }

    public func validate(
        from currentVersion: Int,
        to targetVersion: Int
    ) throws -> MigrationValidationReport {
        if targetVersion < currentVersion {
            throw MigrationRegistryValidationError.downgradeNotSupported(
                current: currentVersion,
                target: targetVersion
            )
        }
        if currentVersion == targetVersion {
            return MigrationValidationReport(warnings: orderWarnings)
        }

        var cursor = currentVersion
        while cursor < targetVersion {
            guard let migration = migrationsByFromVersion[cursor] else {
                throw MigrationRegistryValidationError.missingStep(
                    fromVersion: cursor,
                    targetVersion: targetVersion
                )
            }
            cursor = migration.toVersion
        }

        return MigrationValidationReport(warnings: orderWarnings)
    }

    public func requiredMigrations(
        from currentVersion: Int,
        to targetVersion: Int
    ) throws -> [any Migration] {
        _ = try validate(from: currentVersion, to: targetVersion)
        if currentVersion == targetVersion {
            return []
        }

        var cursor = currentVersion
        var resolved: [any Migration] = []

        while cursor < targetVersion {
            guard let migration = migrationsByFromVersion[cursor] else {
                throw MigrationRegistryValidationError.missingStep(
                    fromVersion: cursor,
                    targetVersion: targetVersion
                )
            }
            resolved.append(migration)
            cursor = migration.toVersion
        }

        return resolved
    }

    private static func detectOrderWarnings(
        migrations: [any Migration]
    ) -> [MigrationRegistryWarning] {
        guard migrations.count > 1 else { return [] }

        var warnings: [MigrationRegistryWarning] = []
        var previousFromVersion = migrations[0].fromVersion

        for index in 1..<migrations.count {
            let current = migrations[index]
            if current.fromVersion < previousFromVersion {
                warnings.append(
                    MigrationRegistryWarning(
                        code: "ORDER_MISMATCH",
                        message: "Migration tanim sirasi fromVersion artan duzende degil (\(current.id))."
                    )
                )
            }
            previousFromVersion = current.fromVersion
        }

        return warnings
    }
}
