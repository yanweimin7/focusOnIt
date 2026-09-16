import Cocoa
import FlutterMacOS

/// 菜单栏常驻 + 窗口收缩/恢复。
///
/// 在插件 setup() 时注册（此时 registrar.messenger 一定可用），
/// 避免宿主 AppDelegate 在 applicationDidFinishLaunching 时
/// FlutterViewController.engine 尚未创建导致通道注册失败。
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.squareLength
    )

    init() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                let image = NSImage(
                    systemSymbolName: "eye",
                    accessibilityDescription: "FocusOnIt"
                )
                image?.isTemplate = true
                button.image = image
            } else {
                button.title = "👁"
            }
            button.action = #selector(toggleWindow(_:))
            button.target = self
        }
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
}