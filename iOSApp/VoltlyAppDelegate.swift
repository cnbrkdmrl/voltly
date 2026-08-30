import UIKit
import VoltlyKit

final class VoltlyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        TelemetryCenter.shared.configureOnLaunch()
        return true
    }
}
