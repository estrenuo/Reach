import Foundation
import UserNotifications

/// Posts a workflow's Post Notification (S-048). macOS asks once whether Reach
/// may notify; when it may not, `denied` runs, so the debugger can say why.
@MainActor
enum WorkflowNotifier {
    private static let presenter = Presenter()

    static func post(title: String, text: String, denied: @escaping @MainActor () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
                denied()
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = text
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// Shows the banner while Reach is in front too, as it is right after Return.
    private final class Presenter: NSObject, UNUserNotificationCenterDelegate {
        nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
            async -> UNNotificationPresentationOptions {
            [.banner, .sound]
        }
    }
}
