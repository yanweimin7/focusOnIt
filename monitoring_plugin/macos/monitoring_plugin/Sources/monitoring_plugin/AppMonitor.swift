import Cocoa

/// NSWorkspace 前台应用监控。
///
/// 监听 `didActivateApplicationNotification`，当前台 App 切换到任意应用时
/// 通过 [onFrontmostChanged] 回调。并提供运行中 App 列表 / 前台 App 查询。
final class AppMonitor {
    private let workspace = NSWorkspace.shared
    private var observer: NSObjectProtocol?

    /// 前台 App 切换回调（激活的应用）。
    var onFrontmostChanged: ((NSRunningApplication) -> Void)?

    var isRunning: Bool { observer != nil }

    func start() {
        guard observer == nil else { return }
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication else { return }
            self?.onFrontmostChanged?(app)
        }
    }

    func stop() {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    /// 运行中的应用列表（仅常规 GUI App：activationPolicy == .regular）。
    func runningApps() -> [[String: Any]] {
        workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted {
                ($0.localizedName ?? "") < ($1.localizedName ?? "")
            }
            .map { MonitoredApp(runningApp: $0).json }
    }

    func frontmostApp() -> [String: Any]? {
        guard let app = workspace.frontmostApplication else { return nil }
        return MonitoredApp(runningApp: app).json
    }

    /// 按 bundleId 查找运行中的应用。
    func runningApp(bundleId: String) -> NSRunningApplication? {
        workspace.runningApplications.first {
            $0.bundleIdentifier == bundleId
        }
    }
}