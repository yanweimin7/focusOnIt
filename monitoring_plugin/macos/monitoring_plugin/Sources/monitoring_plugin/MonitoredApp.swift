import Cocoa

/// 跨边界传递的 App 快照。
struct MonitoredApp {
    let bundleId: String
    let name: String
    let pid: Int
    let isActive: Bool
    let isFinishedLaunching: Bool

    init(runningApp: NSRunningApplication) {
        bundleId = runningApp.bundleIdentifier ?? ""
        name = runningApp.localizedName ?? "Unknown"
        pid = Int(runningApp.processIdentifier)
        isActive = runningApp.isActive
        isFinishedLaunching = runningApp.isFinishedLaunching
    }

    var json: [String: Any] {
        [
            "bundleId": bundleId,
            "name": name,
            "pid": pid,
            "isActive": isActive,
            "isFinishedLaunching": isFinishedLaunching,
        ]
    }
}