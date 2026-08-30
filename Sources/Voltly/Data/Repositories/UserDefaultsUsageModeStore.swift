import Foundation

public final class UserDefaultsUsageModeStore: UsageModeStore {
    private enum Keys {
        static let usageMode = "settings.usage_mode.v1"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadUsageMode() -> UsageMode {
        if let rawValue = defaults.string(forKey: Keys.usageMode),
           let mode = UsageMode(rawValue: rawValue) {
            return mode
        }
        return .balanced
    }

    public func saveUsageMode(_ mode: UsageMode) {
        defaults.set(mode.rawValue, forKey: Keys.usageMode)
    }
}
