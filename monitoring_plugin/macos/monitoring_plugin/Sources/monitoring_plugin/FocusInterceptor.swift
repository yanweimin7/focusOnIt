import Cocoa

/// 前台拦截策略。
///
/// 非白名单 App 激活时立即终止进程：
///   1. 推送 `blocked` 事件（Flutter 记录该次拦截）。
///   2. `terminate()`；失败则 `forceTerminate()`，随后推送 `terminated` 事件。
///
/// 系统基础进程（Finder/Dock 等）以及自身永不拦截。
final class FocusInterceptor {
    var onEvent: ((String, [String: Any]) -> Void)?

    var allowedBundleIds: Set<String> = [] {
        didSet { persistWhitelist() }
    }

    let countdownSeconds = 5

    // 注意：shouldIntercept 用小写比较，此处必须全小写
    private let systemApps: Set<String> = [
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.controlcenter",
        "com.apple.windowmanager",
        "com.apple.appkit.xpc.openandsavepanelservice",
        "com.apple.activitymonitor",
        // Touch ID 系统弹窗（coreautha），拦截会导致指纹验证无响应
        "com.apple.localauthentication.uiagent",
        // 系统密码/授权弹窗（SecurityAgent）
        "com.apple.securityagent",
    ]

    private var defaults: UserDefaults { UserDefaults.standard }

    private func persistWhitelist() {
        defaults.set(Array(allowedBundleIds), forKey: "focusOnIt.whitelist")
    }

    func restore() {
        if let saved = defaults.array(forKey: "focusOnIt.whitelist") as? [String] {
            allowedBundleIds = Set(saved)
        }
        // 自身、系统活动监视器、本地 flutter run 调试应用默认加入白名单
        if let own = Bundle.main.bundleIdentifier {
            allowedBundleIds.insert(own)
        }
        allowedBundleIds.insert("com.apple.ActivityMonitor")
        allowedBundleIds.insert("com.example.flutterQuickjs")
    }

    // MARK: - 判定

    func shouldIntercept(bundleId: String) -> Bool {
        if bundleId.isEmpty { return false }
        if bundleId == Bundle.main.bundleIdentifier { return false }
        if systemApps.contains(bundleId.lowercased()) { return false }
        if allowedBundleIds.contains(bundleId) { return false }
        return true
    }

    // MARK: - 拦截

    func runInterception(_ app: NSRunningApplication) {
        let info = MonitoredApp(runningApp: app)
        guard !info.bundleId.isEmpty else { return }

        emit("blocked", info.json, ["countdown": countdownSeconds])

        // 立即杀掉被限制的 app
        immediateKill(app: app, info: info)
    }

    private func immediateKill(app: NSRunningApplication, info: MonitoredApp) {
        let json = info.json
        if app.terminate() {
            emit("terminated", json, ["force": false])
        } else {
            app.forceTerminate()
            emit("terminated", json, ["force": true])
        }
    }

    // MARK: - 外部主动终止

    private func workspaceApp(bundleId: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleId
        }
    }

    func terminate(_ bundleId: String) {
        guard let app = workspaceApp(bundleId: bundleId) else { return }
        let info = MonitoredApp(runningApp: app).json
        if !app.terminate() {
            app.forceTerminate()
        }
        emit("terminated", info, ["force": false])
    }

    func dispose() {}

    // MARK: - emit

    private func emit(_ event: String, _ info: [String: Any], _ extra: [String: Any]) {
        var data = info
        extra.forEach { data[$0.key] = $0.value }
        onEvent?(event, data)
    }
}
