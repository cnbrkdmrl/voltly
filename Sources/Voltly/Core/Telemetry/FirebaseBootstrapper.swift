import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

public enum FirebaseBootstrapper {
    private static var hasGoogleServiceInfo: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    public static var isAvailableInCurrentBuild: Bool {
        hasGoogleServiceInfo
    }

    public static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        guard hasGoogleServiceInfo else { return false }
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    public static func configureIfNeeded() {
        guard hasGoogleServiceInfo else {
            return
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}
