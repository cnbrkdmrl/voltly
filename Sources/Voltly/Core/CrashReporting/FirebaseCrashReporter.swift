import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

public final class FirebaseCrashReporter: CrashReporting {
    private let fallback: CrashReporting

    public init(fallback: CrashReporting = NoopCrashReporter()) {
        self.fallback = fallback
    }

    public func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        guard FirebaseBootstrapper.isConfigured else {
            fallback.log(message)
            return
        }
        Crashlytics.crashlytics().log(message)
        #else
        fallback.log(message)
        #endif
    }

    public func record(error: Error, additionalInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        guard FirebaseBootstrapper.isConfigured else {
            fallback.record(error: error, additionalInfo: additionalInfo)
            return
        }
        Crashlytics.crashlytics().record(error: error, userInfo: additionalInfo ?? [:])
        #else
        fallback.record(error: error, additionalInfo: additionalInfo)
        #endif
    }
}
