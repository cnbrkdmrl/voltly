import Foundation

@MainActor
public protocol UnplugReminderScheduling {
    func requestAuthorization() async
    func purgeLegacyReminders() async
    func scheduleReminder(after minutes: Int, title: String, message: String) async
}

public final class NoopUnplugReminderScheduler: UnplugReminderScheduling {
    public init() {}

    public func requestAuthorization() async {}
    public func purgeLegacyReminders() async {}
    public func scheduleReminder(after minutes: Int, title: String, message: String) async {}
}

#if os(iOS)
import UserNotifications

public final class IOSUnplugReminderScheduler: UnplugReminderScheduling {
    private enum Constants {
        static let reminderIdentifier = "com.voltly.notifications.unplugReminder"
    }

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func purgeLegacyReminders() async {
        let pending = await center.pendingNotificationRequests()
        let pendingIdentifiers = pending
            .filter { isLegacyReminderContent(title: $0.content.title, body: $0.content.body) }
            .map(\.identifier)

        if !pendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
        }

        let delivered = await center.deliveredNotifications()
        let deliveredIdentifiers = delivered
            .filter { isLegacyReminderContent(title: $0.request.content.title, body: $0.request.content.body) }
            .map { $0.request.identifier }

        if !deliveredIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        }
    }

    public func scheduleReminder(after minutes: Int, title: String, message: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [Constants.reminderIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Constants.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(60, minutes * 60)), repeats: false)
        let request = UNNotificationRequest(
            identifier: Constants.reminderIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func isLegacyReminderContent(title: String, body: String) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedTitle == "voltly" && normalizedBody.contains("prizden ayir") {
            return true
        }

        return normalizedBody.contains("sarj seansini kontrol et") &&
            normalizedBody.contains("prizden ayir")
    }
}
#endif
