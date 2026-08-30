import Foundation

extension VehicleBackupDTO: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: schemaVersion,
            isDeleted: isDeleted
        )
    }
}

extension ChargingSessionBackupDTO: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: schemaVersion,
            isDeleted: isDeleted
        )
    }
}

extension TariffPresetBackupDTO: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: schemaVersion,
            isDeleted: isDeleted
        )
    }
}

extension UserPreferencesBackupDTO: SyncCandidate {
    public var syncMetadata: SyncMetadata {
        SyncMetadata(
            updatedAt: updatedAt,
            schemaVersion: schemaVersion,
            isDeleted: isDeleted
        )
    }
}
