# FocusOnIt

macOS 专注 App：监控前台应用，白名单外的应用一旦激活立即终止进程。仅支持 macOS（Flutter + Swift 原生插件）。

## 特性

- **即开即拦**：非白名单应用切换到前台立即 `terminate()`，失败自动 `forceTerminate()`，无宽限期。
- **系统进程保护**：Dock、通知中心、活动监视器（`com.apple.ActivityMonitor`）等不会被误杀；访达不在保护之列。
- **可定制白名单**：已安装应用列表中勾选放行，白名单持久化（UserDefaults）。
- **密码门**：监控开关、白名单修改需密码验证；验证成功后 1 分钟解锁窗口，之后自动锁定。
- **菜单栏常驻**：无 Dock/任务栏图标（LSUIElement），菜单栏图标随监控状态变色（绿眼/斜线眼）；点击图标展开/收缩主窗口，菜单内含「退出」（需密码）。
- **默认开启**：启动即自动开始监控。

## 构建

前置：Flutter (SDK ≥ 3.12)、Xcode + CocoaPods。

```bash
cd app
flutter analyze && flutter test && flutter build macos --release
```

产物：`app/build/macos/Build/Products/Release/FocusOnIt.app`（未签名）。

> 新增 plugin 原生 Swift 文件后需先 `cd app/macos && pod install` 再构建。

## 使用

1. 启动 FocusOnIt，菜单栏出现眼睛图标（绿色 = 监控中）。
2. 在设置界面启用密码（可选，退出/改设置时要求验证）。
3. 勾选要放行的白名单应用；其余前台应用将被立即终止。

## 架构

```
app/                Flutter UI（状态管理 focus_controller.dart + main.dart）
monitoring_plugin/  Flutter plugin + Swift 原生层
```

事件链路：NSWorkspace 前台切换 → `FocusInterceptor` 判定拦截 → EventChannel → `FocusController` → UI。

- 白名单存取：UserDefaults key `focusOnIt.whitelist`；自身与活动监视器强制写入。
- 密码：SHA-256 加盐摘要，存 `focusOnIt.passwordHash`，不存明文。

详见根目录 `AGENTS.md`。