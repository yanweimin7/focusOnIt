import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 单个 macOS 运行中的 App 信息。
class RunningAppInfo {
  final String bundleId;
  final String name;
  final int pid;
  final bool isActive;
  final bool isFinishedLaunching;

  /// App 图标 PNG 字节（可能为空，UI 需提供兜底渲染）。
  final Uint8List? icon;

  const RunningAppInfo({
    required this.bundleId,
    required this.name,
    required this.pid,
    required this.isActive,
    required this.isFinishedLaunching,
    this.icon,
  });

  factory RunningAppInfo.fromJson(Map<String, dynamic> json) => RunningAppInfo(
        bundleId: (json['bundleId'] ?? '') as String,
        name: (json['name'] ?? 'Unknown') as String,
        pid: (json['pid'] ?? 0) as int,
        isActive: (json['isActive'] ?? false) as bool,
        isFinishedLaunching: (json['isFinishedLaunching'] ?? false) as bool,
        icon: (json['icon'] as Uint8List?),
      );

  Map<String, dynamic> toJson() => {
        'bundleId': bundleId,
        'name': name,
        'pid': pid,
        'isActive': isActive,
        'isFinishedLaunching': isFinishedLaunching,
        if (icon != null) 'icon': icon,
      };
}

/// 生物识别（Touch ID / Face ID）可用性。
class BiometricStatus {
  /// 设备是否可用生物识别（硬件存在且已录入指纹）。
  final bool available;

  /// 识别类型：touchID / faceID / none。
  final String type;

  const BiometricStatus({required this.available, required this.type});
}

/// 单次生物识别验证结果。
class BiometricResult {
  final bool ok;

  /// 结果码：ok / userCancel / authenticationFailed / lockout /
  /// notAvailable / notEnrolled / unknown。
  final String code;

  const BiometricResult({required this.ok, required this.code});
}

/// 原生层推送给 Flutter 的监控事件。
class MonitorEvent {
  /// 事件名：appActivated / blocked / terminated
  final String name;

  /// 事件载荷（含 App 信息 / countdown / force 等）。
  final Map<String, dynamic> data;

  const MonitorEvent({required this.name, required this.data});

  factory MonitorEvent.fromDispatch(String name, Map<String, dynamic> data) =>
      MonitorEvent(name: name, data: data);
}

/// macOS 前台 App 监控 + 专注拦截插件。
///
/// 通过 MethodChannel 与原生 Swift 层通信；原生通过 EventChannel
/// 推流 `appActivated` / `blocked` / `terminated` 等事件，供 [stream] 订阅。
class MonitoringPlugin {
  static const MethodChannel _channel =
      MethodChannel('com.focusonit/monitoring');

  static const EventChannel _events =
      EventChannel('com.focusonit/monitoring/events');

  /// 窗口控制通道（由宿主 App 的 AppDelegate 注册）。
  static const MethodChannel _windowChannel =
      MethodChannel('com.focusonit/window');

  /// 原生事件流（`blocked`、`graceExpired`、`forceSwitched` 等）。
  Stream<MonitorEvent> get stream => _events
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) {
        final map = (e as Map).cast<String, dynamic>();
        final name = (map['event'] ?? 'unknown') as String;
        final data = (map['data'] ?? <String, dynamic>{})
            .cast<String, dynamic>();
        return MonitorEvent.fromDispatch(name, data);
      });

  Future<void> start() async {
    await _channel.invokeMethod('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  Future<bool> isRunning() async {
    return (await _channel.invokeMethod('isRunning')) as bool;
  }

  Future<List<RunningAppInfo>> getRunningApps() async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'getRunningApps',
    );
    return (raw ?? [])
        .map((e) => RunningAppInfo.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<RunningAppInfo?> getFrontmostApp() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getFrontmostApp',
    );
    if (raw == null) return null;
    return RunningAppInfo.fromJson(raw.cast<String, dynamic>());
  }

  /// 设置白名单（bundleId 列表）。立即生效并持久化到原生层。
  Future<void> setWhitelist(List<String> bundleIds) async {
    await _channel.invokeMethod('setWhitelist', bundleIds);
  }

  Future<List<String>> getWhitelist() async {
    final raw = await _channel.invokeListMethod<String>('getWhitelist');
    return raw ?? const [];
  }

  /// 向指定 app 激活（拉回到前台）。
  Future<bool> activateApp(String bundleId) async {
    return (await _channel.invokeMethod('activateApp', bundleId)) as bool;
  }

  /// 隐藏指定 app 的所有窗口。
  Future<bool> hideApp(String bundleId) async {
    return (await _channel.invokeMethod('hideApp', bundleId)) as bool;
  }

  /// 终止指定 app 进程。
  Future<bool> terminateApp(String bundleId) async {
    return (await _channel.invokeMethod('terminateApp', bundleId)) as bool;
  }

  // MARK: - 密码门

  /// 是否已设置保护密码。
  Future<bool> hasPassword() async {
    return (await _channel.invokeMethod('getPasswordStatus')) as bool;
  }

  /// 首次设置保护密码。
  Future<void> setPassword(String password) async {
    await _channel.invokeMethod('setPassword', password);
  }

  /// 验证密码是否正确。未设置密码时返回 true。
  Future<bool> verifyPassword(String password) async {
    return (await _channel.invokeMethod('verifyPassword', password)) as bool;
  }

  // MARK: - 生物识别（Touch ID）

  /// 生物识别可用性（UI 据此决定是否展示指纹入口）。
  Future<BiometricStatus> getBiometricStatus() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'getBiometricStatus',
    );
    return BiometricStatus(
      available: (raw?['available'] ?? false) as bool,
      type: (raw?['type'] ?? 'none') as String,
    );
  }

  /// 弹出系统生物识别验证。取消 / 失败不抛异常，由 [BiometricResult.code] 区分。
  Future<BiometricResult> authenticateBiometric({
    String reason = '验证指纹以解锁 FocusOnIt',
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'authenticateBiometric',
      reason,
    );
    return BiometricResult(
      ok: (raw?['ok'] ?? false) as bool,
      code: (raw?['code'] ?? 'unknown') as String,
    );
  }

  // MARK: - 窗口 / 菜单栏

  /// 收缩到顶部菜单栏（隐藏主窗口，保留状态栏图标）。
  Future<void> collapseToMenuBar() async {
    await _windowChannel.invokeMethod('collapseToMenuBar');
  }

  /// 从菜单栏恢复主窗口。
  Future<void> restoreFromMenuBar() async {
    await _windowChannel.invokeMethod('restoreFromMenuBar');
  }

  /// 主窗口当前是否处于收缩（隐藏）状态。
  Future<bool> isCollapsed() async {
    return (await _windowChannel.invokeMethod('isCollapsed')) as bool;
  }
}