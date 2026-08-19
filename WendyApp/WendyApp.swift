import SwiftUI

@main
struct WendyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Chat sits in the middle but stays the landing tab.
    @State private var selectedTab = 1

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ListView(title: "To-Do", listName: "todo")
                    .tabItem { Label("To-Do", systemImage: "checklist") }
                    .tag(0)
                ChatView()
                    .tabItem { Label("Chat", systemImage: "message") }
                    .tag(1)
                ListView(title: "Shopping", listName: "shopping")
                    .tabItem { Label("Shopping", systemImage: "cart") }
                    .tag(2)
            }
        }
    }
}
