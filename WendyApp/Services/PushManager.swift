import UIKit
import UserNotifications

/// Requests notification permission and registers the APNs device token with every
/// configured agent backend, so `push_phone` from either gateway reaches the phone.
@MainActor
final class PushManager {
    static let shared = PushManager()
    private init() {}

    /// Called on every launch: ask permission, then ask iOS for a remote token.
    /// iOS re-fires `didRegisterForRemoteNotifications` on each launch, so the token
    /// re-POSTs and the server dedups.
    func start() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Register the hex token with each configured agent. Failures are per-agent —
    /// one unreachable/misconfigured gateway doesn't block the other.
    func registerToken(_ hex: String) async {
        for agent in AgentProfile.allCases where Configuration.isConfigured(for: agent) {
            do {
                try await APIService.shared.registerPushToken(hex, agent: agent)
            } catch {
                print("[Push] register failed for \(agent.rawValue): \(error.localizedDescription)")
            }
        }
    }
}
