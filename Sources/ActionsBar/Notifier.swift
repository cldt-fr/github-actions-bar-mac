import AppKit
import ServiceManagement
import UserNotifications

enum Notifier {
    /// Notifications need a real app bundle; `swift run` doesn't provide one.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyCompletion(of run: WorkflowRun) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(RunStatus.emoji(for: run.conclusion)) \(run.workflowName) — \(run.repository.name)"
        let branch = run.headBranch.map { "\($0) · " } ?? ""
        content.body = "\(branch)\(RunStatus.label(status: run.status, conclusion: run.conclusion)) en \(Format.duration(run.duration))\n\(run.displayTitle)"
        content.sound = run.conclusion == "success" ? nil : .default
        content.userInfo = ["url": run.htmlUrl.absoluteString]

        let request = UNNotificationRequest(identifier: "run-\(run.id)-\(run.runAttempt ?? 1)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also hides the Dock icon when launched with `swift run` (no Info.plist).
        NSApp.setActivationPolicy(.accessory)
        if Notifier.isAvailable {
            UNUserNotificationCenter.current().delegate = self
            Notifier.requestAuthorization()
            enableLaunchAtLoginOnFirstRun()
        }
    }

    /// Launch at login is on by default, but only set once so that turning it off in the settings sticks.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("ActionsBar: launch at login failed: \(error)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let string = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: string)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
