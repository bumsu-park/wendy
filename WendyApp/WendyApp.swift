import SwiftUI

@main
struct WendyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}
