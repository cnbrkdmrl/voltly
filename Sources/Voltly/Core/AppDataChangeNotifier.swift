import Foundation

public enum AppDataChangeReason: String, Sendable {
    case backupImport
    case goalUpdate
}

public extension Notification.Name {
    static let voltlyDataDidChange = Notification.Name("com.voltly.dataDidChange")
}

public enum AppDataChangeNotifier {
    public static func post(reason: AppDataChangeReason) {
        NotificationCenter.default.post(
            name: .voltlyDataDidChange,
            object: nil,
            userInfo: ["reason": reason.rawValue]
        )
    }
}
