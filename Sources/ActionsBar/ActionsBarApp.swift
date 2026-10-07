import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

@main
struct ActionsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI lives in an NSStatusItem + NSPopover (see StatusItemController):
        // MenuBarExtra windows drift away from the menu bar when their content resizes.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var store: RunStore?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also hides the Dock icon when launched with `swift run` (no Info.plist).
        NSApp.setActivationPolicy(.accessory)

        let store = RunStore(settings: AppSettings())
        self.store = store
        statusItemController = StatusItemController(store: store)

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

/// Owns the menu bar item and the popover anchored to it.
@MainActor
final class StatusItemController: NSObject {
    private let store: RunStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(store: RunStore) {
        self.store = store
        super.init()

        let hostingController = NSHostingController(rootView: MenuContentView().environment(store))
        // Let the popover follow the SwiftUI content size; it stays anchored to the status item.
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
        }
        observeStore()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Re-renders the status item whenever the store properties it reads change.
    private func observeStore() {
        withObservationTracking {
            updateButton()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStore() }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        guard let first = store.active.first else {
            button.image = NSImage(systemSymbolName: idleSymbol, accessibilityDescription: "ActionsBar")
            button.image?.isTemplate = true
            button.title = ""
            return
        }

        let progress = store.overallProgress
        let percent = "\(Int((progress * 100).rounded()))%"
        let text: String
        if store.active.count > 1 {
            text = "\(store.active.count) · \(percent)"
        } else if store.settings.showNameInMenuBar {
            text = "\(first.run.workflowName) \(percent)"
        } else {
            text = percent
        }

        button.image = ProgressRing.image(progress: progress)
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: " " + text, attributes: [.font: font])
    }

    private var idleSymbol: String {
        if store.errorMessage != nil { return "exclamationmark.triangle" }
        switch store.lastConclusion {
        case "failure", "startup_failure", "timed_out": return "xmark.circle"
        case "success": return "checkmark.circle"
        default: return "circle.dashed"
        }
    }
}

/// Draws a small template ring so it follows the menu bar's light/dark appearance.
enum ProgressRing {
    static func image(progress: Double) -> NSImage {
        let clamped = min(max(progress, 0), 1)
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let lineWidth: CGFloat = 2
            let ringRect = rect.insetBy(dx: lineWidth / 2 + 0.5, dy: lineWidth / 2 + 0.5)

            let track = NSBezierPath(ovalIn: ringRect)
            track.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(0.25).setStroke()
            track.stroke()

            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: NSPoint(x: rect.midX, y: rect.midY),
                radius: ringRect.width / 2,
                startAngle: 90,
                endAngle: 90 - 360 * clamped,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
