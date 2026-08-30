import Foundation

/// V1.5+ senkronizasyon katmanina geciste ortak metadata kapsayicisi.
public struct SyncMetadata: Equatable, Sendable {
    public let updatedAt: Date
    public let schemaVersion: Int
    public let isDeleted: Bool

    public init(updatedAt: Date, schemaVersion: Int, isDeleted: Bool) {
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.isDeleted = isDeleted
    }
}

/// Bulut senkronizasyonu veya import merge motoru icin ortak aday kayit protokolu.
public protocol SyncCandidate {
    var id: UUID { get }
    var syncMetadata: SyncMetadata { get }
}

/// Gelecekteki provider'larda (CloudKit, dosya, API) merge davranisini soyutlamak icin.
public protocol RecordMergable {
    associatedtype Record

    func apply(incoming: Record)
}
