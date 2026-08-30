import Foundation

/// Backup archive schema version.
/// Local app persistence migrations use `LocalSchemaVersion`.
public enum AppSchemaVersion: Int, Codable, CaseIterable, Sendable {
    case v1 = 1

    public static var current: AppSchemaVersion {
        .v1
    }
}
