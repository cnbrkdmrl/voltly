import SwiftUI
import VoltlyKit

@main
struct VoltlyiOSApp: App {
    @UIApplicationDelegateAdaptor(VoltlyAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            VoltlyAppContainerView()
        }
    }
}
