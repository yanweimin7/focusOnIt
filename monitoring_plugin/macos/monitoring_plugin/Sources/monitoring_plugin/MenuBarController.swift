import Cocoa
import FlutterMacOS

/// 菜单栏常驻 + 窗口收缩/恢复 + 退出（需密码）。
///
/// 在插件 setup() 时注册（此时 registrar.messenger 一定可用），
/// 避免宿主 AppDelegate 在 applicationDidFinishLaunching 时
/// FlutterViewController.engine 尚未创建导致通道注册失败。
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.squareLength
    )
    private let menu = NSMenu()
    private let passwordGate: PasswordGate
    private var isMonitoring = false

    init(passwordGate: PasswordGate) {
        self.passwordGate = passwordGate
        super.init()
        setupMenu()
        updateMonitoring(false)
    }

    private func setupMenu() {
        menu.delegate = self

        let toggleItem = NSMenuItem(
            title: "隐藏主窗口",
            action: #selector(toggleWindow(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 FocusOnIt…",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// 更新菜单栏图标的监控状态：开启→绿色实心眼，关闭→斜线眼。
    func updateMonitoring(_ running: Bool) {
        isMonitoring = running
        guard let button = statusItem.button else { return }
        if #available(macOS 11.0, *) {
            let name = running ? "eye.fill" : "eye.slash"
            guard let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: "FocusOnIt"
            ) else { return }
            if running {
                image.size = NSSize(width: 18, height: 18)
                button.image = image.tinted(with: .systemGreen)
            } else {
                image.isTemplate = true
                button.image = image
            }
        } else {
            button.title = running ? "👁" : "🚫"
        }
        button.toolTip = running ? "FocusOnIt - 监控中" : "FocusOnIt - 已暂停"
    }

    func mainWindow() -> NSWindow? {
        NSApp.mainWindow ?? NSApp.windows.first
    }

    func isCollapsed() -> Bool {
        (mainWindow()?.isVisible ?? false) == false
    }

    func collapse() {
        mainWindow()?.orderOut(nil)
    }

    func restore() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow()?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleWindow(_ sender: Any?) {
        if isCollapsed() {
            restore()
        } else {
            collapse()
        }
    }

    @objc private func quit(_ sender: Any?) {
        // 未设置密码时允许直接退出
        guard passwordGate.isSet else {
            NSApp.terminate(nil)
            return
        }

        let alert = NSAlert()
        alert.messageText = "退出 FocusOnIt"
        alert.informativeText = "请输入密码后退出："
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if passwordGate.verify(field.stringValue) {
            NSApp.terminate(nil)
        } else {
            let error = NSAlert()
            error.messageText = "密码错误"
            error.informativeText = "无法退出 FocusOnIt。"
            error.runModal()
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(at: 0)?.title = isCollapsed() ? "显示主窗口" : "隐藏主窗口"
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}