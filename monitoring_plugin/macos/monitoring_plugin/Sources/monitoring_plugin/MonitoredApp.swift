import Cocoa

/// 跨边界传递的 App 快照。
struct MonitoredApp {
    let bundleId: String
    let name: String
    let pid: Int
    let isActive: Bool
    let isFinishedLaunching: Bool
    let iconPNG: Data?

    init(
        runningApp: NSRunningApplication,
        iconPNG: Data? = nil
    ) {
        bundleId = runningApp.bundleIdentifier ?? ""
        name = runningApp.localizedName ?? "Unknown"
        pid = Int(runningApp.processIdentifier)
        isActive = runningApp.isActive
        isFinishedLaunching = runningApp.isFinishedLaunching
        self.iconPNG = iconPNG
    }

    init(
        bundleId: String,
        name: String,
        pid: Int,
        isActive: Bool,
        isFinishedLaunching: Bool,
        iconPNG: Data? = nil
    ) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
        self.isActive = isActive
        self.isFinishedLaunching = isFinishedLaunching
        self.iconPNG = iconPNG
    }

    var json: [String: Any] {
        var dict: [String: Any] = [
            "bundleId": bundleId,
            "name": name,
            "pid": pid,
            "isActive": isActive,
            "isFinishedLaunching": isFinishedLaunching,
        ]
        if let iconPNG {
            dict["icon"] = iconPNG
        }
        return dict
    }
}

/// 把 NSImage 渲染成指定尺寸的 PNG，供跨通道传输。
enum IconRenderer {
    static func pngData(from image: NSImage, size: CGFloat = 48) -> Data? {
        let px = Int(size)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px,
            pixelsHigh: px,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}