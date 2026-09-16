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

    /// 应用列表：所有已安装 App + 运行中 App（按名称排序去重）。
    /// 白名单需要覆盖未启动的应用，仅列运行中的会缺一堆。
    /// 自身 App 不出现在列表里。
    func runningApps() -> [[String: Any]] {
        var byBundleId: [String: [String: Any]] = [:]

        let selfId = Bundle.main.bundleIdentifier

        let installed = installedApps()
        for json in installed {
            if let bid = json["bundleId"] as? String, bid != selfId {
                byBundleId[bid] = json
            }
        }

        for app in workspace.runningApplications
            .filter({ $0.activationPolicy == .regular }) {
            guard app.bundleIdentifier != selfId else { continue }
            let json = MonitoredApp(runningApp: app).json
            if let bid = json["bundleId"] as? String {
                byBundleId[bid] = json   // 运行中的信息覆盖安装目录信息
            }
        }

        return byBundleId.values.sorted {
            ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "")
        }
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

    // MARK: - 已安装应用枚举

    /// 扫描常用安装目录收集所有 .app。
    private func installedApps() -> [[String: Any]] {
        let roots = [
            "/Applications",
            "/System/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
        ]
        var result: [String: [String: Any]] = [:]
        for root in roots {
            collectApps(at: root, depth: 0, into: &result)
        }
        return Array(result.values)
    }

    /// 递归查找 .app（跳过 .app 内部目录，避免遍历整个 bundle）。
    private func collectApps(
        at dir: String, depth: Int, into out: inout [String: [String: Any]]
    ) {
        guard depth <= 4 else { return }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for entry in entries {
            let path = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }

            if isDir.boolValue, entry.hasSuffix(".app") {
                if let json = bundleJson(at: path),
                   let bid = json["bundleId"] as? String {
                    out[bid] = json
                }
            } else if isDir.boolValue {
                collectApps(at: path, depth: depth + 1, into: &out)
            }
        }
    }

    /// 读取 .app 的 bundleId + 显示名。
    private func bundleJson(at path: String) -> [String: Any]? {
        guard let bundle = Bundle(path: path),
              let bid = bundle.bundleIdentifier,
              !bid.isEmpty else { return nil }
        let name = bundle.localizedInfoDictionary?["CFBundleName"] as? String
            ?? bundle.infoDictionary?["CFBundleName"] as? String
            ?? (path as NSString).lastPathComponent
        return [
            "bundleId": bid,
            "name": name,
            "pid": 0,
            "isActive": false,
            "isFinishedLaunching": false,
        ]
    }
}