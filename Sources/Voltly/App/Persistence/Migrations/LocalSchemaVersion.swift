import Foundation

/// Local persistence schema version for app-side upgrades.
/// This is intentionally separate from backup export/import schema versioning.
public enum LocalSchemaVersion: Int, Codable, CaseIterable, Sendable {
    case v1 = 1
    case v2 = 2
    case v3 = 3
    case v4 = 4
    case v5 = 5
    case v6 = 6

    public static var current: LocalSchemaVersion {
        .v6
    }
}
