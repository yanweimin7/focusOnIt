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

  bool get isBlock => event == 'blocked' || event == 'terminated';
}

/// 一次全屏倒计时拦截会话。
class BlockSession {
  final String bundleId;
  final String appName;
  int seconds;

  BlockSession({
    required this.bundleId,
    required this.appName,
    required this.seconds,
  });
}

/// 全局状态控制器：封装 [MonitoringPlugin] + 事件流。
class FocusController extends ChangeNotifier {
  final MonitoringPlugin _plugin = MonitoringPlugin();
  StreamSubscription<MonitorEvent>? _eventSub;
  Timer? _blockTimer;

  bool ready = false;
  bool monitoring = false;
  List<RunningAppInfo> runningApps = [];
  RunningAppInfo? frontmost;
  List<String> whitelist = [];
  BlockSession? blocking;
  final List<ActivityItem> activities = [];

  Future<void> init() async {
    if (ready) return;
    _eventSub = _plugin.stream.listen(_onEvent);
    try {
      await _refreshAll();
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
    monitoring = await _plugin.isRunning();
  }

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
      _startBlockSession(e.data);
      _pushActivity('blocked', appName, '${e.data["countdown"]} 秒后将终止');
      return;
    }

    if (e.name == 'terminated') {
      _clearBlockSession();
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

  void _startBlockSession(Map<String, dynamic> data) {
    _blockTimer?.cancel();
    blocking = BlockSession(
      bundleId: (data['bundleId'] ?? '') as String,
      appName: (data['name'] ?? '未知') as String,
      seconds: (data['countdown'] as num?)?.toInt() ?? 5,
    );
    _blockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      blocking!.seconds -= 1;
      if (blocking!.seconds <= 0) {
        _blockTimer?.cancel();
        _blockTimer = null;
        blocking = null;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearBlockSession() {
    _blockTimer?.cancel();
    _blockTimer = null;
    if (blocking != null) {
      blocking = null;
      notifyListeners();
    }
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
    _blockTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}