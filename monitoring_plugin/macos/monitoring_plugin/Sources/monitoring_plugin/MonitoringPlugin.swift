import Cocoa
import FlutterMacOS

public class MonitoringPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MonitoringPlugin()
        instance.setup(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
    }

    private var channel: FlutterMethodChannel!
    private var windowChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?

    private let monitor = AppMonitor()
    private let interceptor = FocusInterceptor()
    private let passwordGate = PasswordGate()
    private lazy var menuBar = MenuBarController(passwordGate: passwordGate)
    private var whitelist: Set<String> = []

    private func setup(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger

        channel = FlutterMethodChannel(
            name: "com.focusonit/monitoring",
            binaryMessenger: messenger
        )

        let eventChannel = FlutterEventChannel(
            name: "com.focusonit/monitoring/events",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)

        // 窗口 / 菜单栏控制（在插件 setup 时注册，messenger 必然可用）
        let window = FlutterMethodChannel(
            name: "com.focusonit/window",
            binaryMessenger: messenger
        )
        window.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterMethodNotImplemented)
                return
            }
            switch call.method {
            case "collapseToMenuBar":
                self.menuBar.collapse()
                result(true)
            case "restoreFromMenuBar":
                self.menuBar.restore()
                result(true)
            case "isCollapsed":
                result(self.menuBar.isCollapsed())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        windowChannel = window

        // 原生 → 插件 → Flutter 事件链路
        monitor.onFrontmostChanged = { [weak self] app in
            self?.handleActivated(app)
        }
        interceptor.onEvent = { [weak self] event, data in
            self?.send(event: event, data: data)
        }
        interceptor.restore()
        whitelist = interceptor.allowedBundleIds
        menuBar.updateMonitoring(monitor.isRunning)
    }

    // MARK: - MethodChannel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            monitor.start()
            menuBar.updateMonitoring(true)
            result(true)

        case "stop":
            monitor.stop()
            menuBar.updateMonitoring(false)
            result(true)

        case "isRunning":
            result(monitor.isRunning)

        case "getRunningApps":
            result(monitor.runningApps())

        case "getFrontmostApp":
            result(monitor.frontmostApp())

        case "setWhitelist":
            guard let ids = call.arguments as? [String] else {
                result(FlutterError(code: "bad_args", message: "expected [String]", details: nil))
                return
            }
            whitelist = Set(ids)
            interceptor.allowedBundleIds = whitelist
            result(true)

        case "getWhitelist":
            result(Array(interceptor.allowedBundleIds))

        case "activateApp":
            guard let bid = call.arguments as? String else {
                result(false)
                return
            }
            result(activate(bundleId: bid))

        case "hideApp":
            guard let bid = call.arguments as? String else {
                result(false)
                return
            }
            guard let app = monitor.runningApp(bundleId: bid) else {
                result(false)
                return
            }
            result(app.hide())

        case "terminateApp":
            guard let bid = call.arguments as? String else {
                result(false)
                return
            }
            interceptor.terminate(bid)
            result(true)

        case "getPasswordStatus":
            result(passwordGate.isSet)

        case "setPassword":
            guard let pwd = call.arguments as? String, !pwd.isEmpty else {
                result(FlutterError(code: "bad_args", message: "expected non-empty String", details: nil))
                return
            }
            passwordGate.set(pwd)
            result(true)

        case "verifyPassword":
            guard let pwd = call.arguments as? String else {
                result(false)
                return
            }
            result(passwordGate.verify(pwd))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func activate(bundleId: String) -> Bool {
        if bundleId.isEmpty || bundleId == Bundle.main.bundleIdentifier {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            return true
        }
        guard let app = monitor.runningApp(bundleId: bundleId) else { return false }
        return app.activate(options: [.activateAllWindows])
    }

    // MARK: - 前台切换处理

    private func handleActivated(_ app: NSRunningApplication) {
        let info = MonitoredApp(runningApp: app).json

        if interceptor.shouldIntercept(bundleId: info["bundleId"] as? String ?? "") {
            // 触发全屏倒计时拦截（5s 后终止进程）
            interceptor.runInterception(app)
        } else {
            // 白名单 / 自身：仅广播激活事件
            send(event: "appActivated", data: info)
        }
    }

    // MARK: - EventChannel

    private func send(event: String, data: [String: Any]) {
        eventSink?(["event": event, "data": data])
    }
}

// MARK: - FlutterStreamHandler

extension MonitoringPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}