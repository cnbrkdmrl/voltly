import Foundation

@MainActor
public final class BackupUpsellBannerCoordinator: ObservableObject {
    private enum Keys {
        static let lastDismissDate = "backup_upsell_banner.last_dismiss_date"
    }

    private enum Rules {
        static let minimumSessionCount = 3
        static let redisplayInterval: TimeInterval = 7 * 24 * 60 * 60
    }

    @Published public private(set) var isVisible = false

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func evaluate(
        sessionState: SessionState,
        totalSessionCount: Int,
        now: Date = .now
    ) {
        guard sessionState.isGuest,
              totalSessionCount >= Rules.minimumSessionCount else {
            isVisible = false
            return
        }

        if let dismissedAt = defaults.object(forKey: Keys.lastDismissDate) as? Date {
            let elapsed = now.timeIntervalSince(dismissedAt)
            guard elapsed >= Rules.redisplayInterval else {
                isVisible = false
                return
            }
        }

        isVisible = true
    }

    public func dismiss(now: Date = .now) {
        defaults.set(now, forKey: Keys.lastDismissDate)
        isVisible = false
    }
}
