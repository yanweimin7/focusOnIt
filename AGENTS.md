# AGENTS.md

FocusOnIt: macOS 专注 App — 前台 App 监控，白名单外应用激活即杀。Flutter + Swift 原生插件，仅支持 macOS。

## 结构

- `app/` — Flutter macOS 应用（bundle id `com.focusonit.focusOnIt`），UI 层：`lib/focus_controller.dart`（状态管理）、`lib/main.dart`。
- `monitoring_plugin/` — Flutter plugin，原生 Swift 在 `monitoring_plugin/macos/monitoring_plugin/Sources/monitoring_plugin/`。`app/pubspec.yaml` 以 `path: ../monitoring_plugin` 引入。

## 命令（在 `app/` 目录下运行）

- 验证：`flutter analyze && flutter test && flutter build macos --debug`
- 发布包：`flutter build macos --release` → `build/macos/Build/Products/Release/FocusOnIt.app`（未签名）

## 硬性要点

- **新增 Swift 文件后必须 `cd app/macos && pod install`**，否则 Pods 项目文件清单不含新文件，编译报"no rule to process file"。改已有文件不需要。
- 窗口控制通道 `com.focusonit/window` 在插件 `setup()` 里注册，**不能在 AppDelegate 注册**（finishLaunching 时 engine 未创建会失败）。AppDelegate 已精简，只保留 `applicationShouldTerminateAfterLastWindowClosed=false`。
- 沙盒已关闭（`app/macos/Runner/*.entitlements` 均 `com.apple.security.app-sandbox=false`），terminate/hide 其他 App 必需，勿恢复。
- `app/macos/Runner/Info.plist` 有 `LSUIElement=true`：无 Dock/任务栏图标，纯菜单栏应用。

## 原生层分工（Sources/monitoring_plugin/）

- `AppMonitor.swift` — NSWorkspace 前台切换监听 + 已安装 App 扫描；`isRunning` = observer 存在。
- `FocusInterceptor.swift` — 核心拦截：`shouldIntercept` 跳过空 bundleId / 自身 `Bundle.main.bundleIdentifier` / `systemApps` / 白名单；命中即 `terminate()`，失败 `forceTerminate()`。**无倒计时/宽限期**。`systemApps`（ck Dock 等）含 `com.apple.ActivityMonitor`，访达不在其中（可被拦截）。**`systemApps` 必须全小写**（比较时 `bundleId.lowercased()`）；已含 Touch ID 弹窗 `com.apple.localauthentication.uiagent`（coreautha，拦截会导致指纹验证无响应）与 `com.apple.securityagent`。
- `MonitoringPlugin.swift` — MethodChannel `com.focusonit/monitoring`、EventChannel `com.focusonit/monitoring/events`、窗口通道 + 各组件装配。MethodChannel 的 `start/stop` 会同步菜单栏图标状态。
- `PasswordGate.swift` — 密码仅存 SHA-256 摘要（盐 `focusOnIt.v1`，UserDefaults `focusOnIt.passwordHash`）；**未设置密码时 `verify` 恒通过**，只有设置过密码才拦截（菜单栏退出也遵循此逻辑）。
- `BiometricAuth.swift` — Touch ID 封装（LocalAuthentication）：`status` 供 UI 判断入口，`authenticate` 回调结果码（userCancel / authenticationFailed / lockout / notEnrolled / notAvailable）；指纹不可用时调用方回退密码。
- `MenuBarController.swift` — 菜单栏图标 + 下拉菜单（显示/隐藏主窗口、退出需密码）。退出流程：密码已设置且指纹可用时先弹 Touch ID（取消即中止），失败回退密码框。图标随监控状态变色：开→绿色 `eye.fill`，关→斜线 `eye.slash`。
- 白名单持久化：UserDefaults `focusOnIt.whitelist`；`restore()` 强制写入自身、`com.apple.ActivityMonitor` 与本地调试应用 `com.example.flutterQuickjs`（flutter run 开发时勿被拦截）。

## 事件约定（事件链路：原生 → plugin stream → FocusController notifyListeners）

- `blocked` 事件不再记录（拦截即杀），`terminated` 才记录，`detail` 区分「已自行退出/已终止/已强制终止」。
- UI 测试改用例时注意事件字段名（参考 `app/test/widget_test.dart`）。

## UI 约定（app/lib/main.dart）

- 敏感操作（监控开关、白名单修改）须经密码门：`_LockButton` + `_PasswordDialog` + `_guardedChange` 模式；设置密码后修改需验证，解锁窗口 1 分钟由 `Timer` 自动锁定。
- `_PasswordDialog` 解锁模式：指纹可用（`FocusController.biometricAvailable`）时打开即自动弹 Touch ID，同时保留指纹按钮与密码输入兜底；取消系统弹窗不报错，其余失败码映射为中文提示。
- 监控默认开启：`FocusController.init()` 若未运行会自动 `start()`。