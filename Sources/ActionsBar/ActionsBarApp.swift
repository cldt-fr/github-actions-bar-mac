import AppKit
import SwiftUI

@main
struct ActionsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = RunStore(settings: AppSettings())

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(store)
        } label: {
            StatusBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// What is shown in the menu bar itself.
struct StatusBarLabel: View {
    let store: RunStore

    var body: some View {
        if let first = store.active.first {
            HStack(spacing: 4) {
                Image(nsImage: ProgressRing.image(progress: store.overallProgress))
                Text(text(first: first))
                    .monospacedDigit()
            }
        } else {
            Image(systemName: idleSymbol)
        }
    }

    private func text(first: ActiveRun) -> String {
        let percent = "\(Int((store.overallProgress * 100).rounded()))%"
        if store.active.count > 1 {
            return "\(store.active.count) · \(percent)"
        }
        if store.settings.showNameInMenuBar {
            return "\(first.run.workflowName) \(percent)"
        }
        return percent
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
