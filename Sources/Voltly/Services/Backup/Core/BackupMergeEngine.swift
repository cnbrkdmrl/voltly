import Foundation

public struct BackupMergeEngine {
    public init() {}

    public func decide(local: SyncMetadata?, incoming: SyncMetadata) -> BackupMergeDecision {
        decide(localUpdatedAt: local?.updatedAt, incomingUpdatedAt: incoming.updatedAt)
    }

    public func decide<LocalRecord: SyncCandidate, IncomingRecord: SyncCandidate>(
        local: LocalRecord?,
        incoming: IncomingRecord
    ) -> BackupMergeDecision {
        guard let local else {
            return .inserted
        }

        guard local.id == incoming.id else {
            return .failed(reason: "Kayit kimligi eslesmedigi icin birlestirme yapilamadi.")
        }

        return decide(local: local.syncMetadata, incoming: incoming.syncMetadata)
    }

    public func decide(localUpdatedAt: Date?, incomingUpdatedAt: Date) -> BackupMergeDecision {
        guard let localUpdatedAt else {
            return .inserted
        }

        if incomingUpdatedAt > localUpdatedAt {
            return .updated
        }

        return .skipped
    }
}
