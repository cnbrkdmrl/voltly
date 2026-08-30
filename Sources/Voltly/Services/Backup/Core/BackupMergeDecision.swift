import Foundation

public enum BackupMergeDecision: Equatable, Sendable {
    case inserted
    case updated
    case skipped(reason: String)
    case failed(reason: String)

    public static var skipped: BackupMergeDecision {
        .skipped(reason: "Yerel veri daha guncel oldugu icin atlandi.")
    }
}
