import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    /// Watch the N repositories you pushed to most recently.
    var autoDiscover: Bool {
        didSet { UserDefaults.standard.set(autoDiscover, forKey: "autoDiscover") }
    }
    var autoDiscoverCount: Int {
        didSet { UserDefaults.standard.set(autoDiscoverCount, forKey: "autoDiscoverCount") }
    }
    /// Extra repositories, as `owner/name`.
    var pinnedRepos: [String] {
        didSet { UserDefaults.standard.set(pinnedRepos, forKey: "pinnedRepos") }
    }
    /// Seconds between refreshes while at least one run is in progress.
    var activeInterval: Int {
        didSet { UserDefaults.standard.set(activeInterval, forKey: "activeInterval") }
    }
    /// Seconds between refreshes when nothing is running.
    var idleInterval: Int {
        didSet { UserDefaults.standard.set(idleInterval, forKey: "idleInterval") }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    /// Show the workflow name next to the progress ring in the menu bar.
    var showNameInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showNameInMenuBar, forKey: "showNameInMenuBar") }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("ActionsBar: launch at login failed: \(error)")
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        autoDiscover = defaults.object(forKey: "autoDiscover") as? Bool ?? true
        autoDiscoverCount = defaults.object(forKey: "autoDiscoverCount") as? Int ?? 15
        pinnedRepos = defaults.stringArray(forKey: "pinnedRepos") ?? []
        activeInterval = defaults.object(forKey: "activeInterval") as? Int ?? 5
        idleInterval = defaults.object(forKey: "idleInterval") as? Int ?? 30
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        showNameInMenuBar = defaults.object(forKey: "showNameInMenuBar") as? Bool ?? false
    }
}
