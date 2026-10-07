import SwiftUI

/// Maps GitHub status/conclusion pairs to labels, symbols and colors.
enum RunStatus {
    static func label(status: String?, conclusion: String?) -> String {
        switch status {
        case "queued", "requested", "pending": return "En file d'attente"
        case "waiting": return "En attente d'approbation"
        case "in_progress": return "En cours"
        default: break
        }
        switch conclusion {
        case "success": return "Réussi"
        case "failure": return "Échec"
        case "cancelled": return "Annulé"
        case "skipped": return "Ignoré"
        case "timed_out": return "Délai dépassé"
        case "action_required": return "Action requise"
        case "startup_failure": return "Échec au démarrage"
        case "neutral": return "Neutre"
        default: return conclusion ?? status ?? "Inconnu"
        }
    }

    static func symbol(status: String?, conclusion: String?) -> String {
        switch status {
        case "queued", "requested", "pending": return "clock"
        case "waiting": return "hourglass"
        case "in_progress": return "arrow.triangle.2.circlepath"
        default: break
        }
        switch conclusion {
        case "success": return "checkmark.circle.fill"
        case "failure", "startup_failure": return "xmark.circle.fill"
        case "timed_out": return "clock.badge.xmark"
        case "cancelled": return "stop.circle"
        case "skipped": return "minus.circle"
        case "action_required": return "exclamationmark.circle.fill"
        default: return "circle"
        }
    }

    static func color(status: String?, conclusion: String?) -> Color {
        switch status {
        case "queued", "requested", "pending", "waiting": return .orange
        case "in_progress": return .yellow
        default: break
        }
        switch conclusion {
        case "success": return .green
        case "failure", "startup_failure", "timed_out": return .red
        case "action_required": return .orange
        default: return .secondary
        }
    }

    static func emoji(for conclusion: String?) -> String {
        switch conclusion {
        case "success": "✅"
        case "failure", "startup_failure", "timed_out": "❌"
        case "cancelled": "⏹"
        default: "⚪️"
        }
    }
}

enum Format {
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m\(String(format: "%02d", seconds % 60))s" }
        return "\(seconds / 3600)h\(String(format: "%02d", (seconds % 3600) / 60))"
    }
}
