import Foundation
import UserNotifications

final class PostureNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("Notification authorization failed: %@", error.localizedDescription) }
        }
    }

    func sendPostureChange() {
        // Read the current setting so changes in System Settings take effect
        // without restarting the app. Never prompt from a sensor callback.
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Posture changed"
            content.body = "Your posture has shifted from your calibrated position. Check your position and sit comfortably upright."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "upright.posture-change", content: content, trigger: nil)
            self?.center.add(request) { error in
                if let error { NSLog("Posture notification failed: %@", error.localizedDescription) }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
