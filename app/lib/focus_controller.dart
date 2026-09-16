import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:monitoring_plugin/monitoring_plugin.dart';

/// 一条拦截/激活事件记录。
class ActivityItem {
  final DateTime time;
  final String event;
  final String appName;
  final String? detail;

  const ActivityItem({
    required this.time,
    required this.event,
    required this.appName,
    this.detail,
  });

  String get label {
    const map = {
      'appActivated': '激活',
      'blocked': '拦截',
      'terminated': '已终止',
    };
    return map[event] ?? event;
  }

  bool get isBlock => event == 'terminated';
}

/// 全局状态控制器：封装 [MonitoringPlugin] + 事件流。
class FocusController extends ChangeNotifier {
  final MonitoringPlugin _plugin = MonitoringPlugin();
  StreamSubscription<MonitorEvent>? _eventSub;

  bool ready = false;
  bool monitoring = false;
  List<RunningAppInfo> runningApps = [];
  RunningAppInfo? frontmost;
  List<String> whitelist = [];
  final List<ActivityItem> activities = [];

  /// 是否已设置保护密码。
  bool passwordSet = false;

  /// 解锁有效截止时间（未解锁为 null）。
  DateTime? _unlockedUntil;
  Timer? _lockTimer;
  static const Duration _unlockWindow = Duration(minutes: 1);

  /// 当前是否处于已解锁状态（1 分钟内通过密码验证）。
  bool get isUnlocked => _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  /// 白名单内排在顶部，其余按名称字母排序。
  List<RunningAppInfo> get sortedApps =>
      List<RunningAppInfo>.from(runningApps)
        ..sort((a, b) {
          final aAllowed = whitelist.contains(a.bundleId);
          final bAllowed = whitelist.contains(b.bundleId);
          if (aAllowed != bAllowed) return aAllowed ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  Future<void> init() async {
    if (ready) return;
    _eventSub = _plugin.stream.listen(_onEvent);
    try {
      await _refreshAll();
      if (!monitoring) {
        await _plugin.start(); // 默认开启监控
        monitoring = true;
      }
      ready = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[FocusController] init failed: $e\n$st');
    }
  }

  Future<void> _refreshAll() async {
    runningApps = await _plugin.getRunningApps();
    frontmost = await _plugin.getFrontmostApp();
    whitelist = await _plugin.getWhitelist();
    passwordSet = await _plugin.hasPassword();
    monitoring = await _plugin.isRunning();
  }

  // MARK: - 密码门

  /// 验证密码并解锁 1 分钟。返回是否验证通过。
  Future<bool> unlock(String password) async {
    final ok = await _plugin.verifyPassword(password);
    if (ok) {
      _beginUnlockWindow();
      notifyListeners();
    }
    return ok;
  }

  /// 立即锁定（清除解锁状态）。
  void lock() {
    _lockTimer?.cancel();
    _lockTimer = null;
    _unlockedUntil = null;
    notifyListeners();
  }

  Future<void> setPassword(String password) async {
    await _plugin.setPassword(password);
    passwordSet = true;
    _beginUnlockWindow();
    notifyListeners();
  }

  /// 开启解锁窗口并安排 1 分钟后自动锁定。
  void _beginUnlockWindow() {
    _lockTimer?.cancel();
    _unlockedUntil = DateTime.now().add(_unlockWindow);
    _lockTimer = Timer(_unlockWindow, lock);
  }

  // MARK: - 窗口 / 菜单栏

  Future<void> collapseToMenuBar() => _plugin.collapseToMenuBar();

  Future<void> restoreFromMenuBar() => _plugin.restoreFromMenuBar();

  Future<void> startMonitoring() async {
    await _plugin.start();
    monitoring = true;
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    await _plugin.stop();
    monitoring = false;
    notifyListeners();
  }

  Future<void> toggleMonitoring() {
    return monitoring ? stopMonitoring() : startMonitoring();
  }

  Future<void> refreshApps() async {
    runningApps = await _plugin.getRunningApps();
    frontmost = await _plugin.getFrontmostApp();
    notifyListeners();
  }

  Future<void> toggleWhitelist(String bundleId, bool allow) async {
    final next = Set<String>.from(whitelist);
    if (allow) {
      next.add(bundleId);
    } else {
      next.remove(bundleId);
    }
    await _plugin.setWhitelist(next.toList());
    whitelist = next.toList();
    notifyListeners();
  }

  Future<bool> hideApp(String bundleId) => _plugin.hideApp(bundleId);

  Future<bool> activateApp(String bundleId) => _plugin.activateApp(bundleId);

  Future<void> terminateApp(String bundleId) async {
    await _plugin.terminateApp(bundleId);
    await refreshApps();
  }

  void _onEvent(MonitorEvent e) {
    final appName = (e.data['name'] ?? '未知') as String;

    if (e.name == 'appActivated') {
      frontmost = RunningAppInfo.fromJson(e.data);
      notifyListeners();
      return;
    }

    if (e.name == 'blocked') {
      // 拦截即杀，无需记录中间状态
      return;
    }

    if (e.name == 'terminated') {
      final force = e.data['force'] == true;
      final alreadyClosed = e.data['alreadyClosed'] == true;
      final detail = alreadyClosed
          ? '已自行退出'
          : (force ? '已强制终止' : '已终止');
      _pushActivity('terminated', appName, detail);
      return;
    }

    _pushActivity(e.name, appName, null);
  }

  void _pushActivity(String event, String appName, String? detail) {
    activities.insert(
      0,
      ActivityItem(time: DateTime.now(), event: event, appName: appName, detail: detail),
    );
    if (activities.length > 100) {
      activities.removeRange(100, activities.length);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}