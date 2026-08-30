import Foundation

public struct AppReleaseVersion: Equatable, Sendable {
    public let appVersion: String
    public let buildNumber: String

    public init(appVersion: String, buildNumber: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}

public final class AppVersionManager {
    private enum Keys {
        static let lastLaunchedAppVersion = "app.version.last_launched"
        static let lastLaunchedBuildNumber = "app.build.last_launched"
    }

    private enum Constants {
        static let fallbackAppVersion = "1.0.0"
        static let fallbackBuildNumber = "1"
    }

    private let bundle: Bundle
    private let defaults: UserDefaults

    public init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) {
        self.bundle = bundle
        self.defaults = defaults
    }

    public var currentReleaseVersion: AppReleaseVersion {
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        return AppReleaseVersion(
            appVersion: appVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? Constants.fallbackAppVersion,
            buildNumber: buildNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? Constants.fallbackBuildNumber
        )
    }

    public var lastLaunchedReleaseVersion: AppReleaseVersion? {
        guard let appVersion = defaults.string(forKey: Keys.lastLaunchedAppVersion),
              let buildNumber = defaults.string(forKey: Keys.lastLaunchedBuildNumber) else {
            return nil
        }
        return AppReleaseVersion(appVersion: appVersion, buildNumber: buildNumber)
    }

    public func markCurrentReleaseAsLaunched() {
        let current = currentReleaseVersion
        defaults.set(current.appVersion, forKey: Keys.lastLaunchedAppVersion)
        defaults.set(current.buildNumber, forKey: Keys.lastLaunchedBuildNumber)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
