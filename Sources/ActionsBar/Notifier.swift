import Foundation
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
