import 'package:flutter/material.dart';
import 'package:monitoring_plugin/monitoring_plugin.dart';

import 'focus_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusOnItApp());
}

/// 通过 InheritedWidget 向下传递 [FocusController]。
class _Scope extends InheritedWidget {
  final FocusController controller;

  const _Scope({required this.controller, required super.child});

  static FocusController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_Scope>()!
        .controller;
  }

  @override
  bool updateShouldNotify(_Scope oldWidget) => true;
}

class FocusOnItApp extends StatefulWidget {
  const FocusOnItApp({super.key});

  @override
  State<FocusOnItApp> createState() => _FocusOnItAppState();
}

class _FocusOnItAppState extends State<FocusOnItApp> {
  final FocusController _controller = FocusController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _controller.init();
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusOnIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: _Scope(
        controller: _controller,
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, color: Color(0xFF5C6BC0)),
                SizedBox(width: 8),
                Text(
                  'FocusOnIt',
                  style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: Icon(
                    controller.monitoring
                        ? Icons.remove_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: controller.monitoring ? Colors.green : Colors.grey,
                  ),
                  label: Text(
                    controller.monitoring ? '监控中' : '已暂停',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          body: controller.ready
              ? const _DashLayout()
              : const Center(child: CircularProgressIndicator()),
        ),
        if (controller.blocking != null) _BlockOverlay(session: controller.blocking!),
      ],
    );
  }
}

/// 全屏倒计时遮罩：拦截发生时铺满整个窗口（原生已切全屏）。
class _BlockOverlay extends StatelessWidget {
  final BlockSession session;

  const _BlockOverlay({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC101525),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 72, color: Colors.white70),
          const SizedBox(height: 24),
          Text(
            session.appName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '不在白名单中，倒计时结束后将终止进程',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 36),
          Text(
            '${session.seconds}',
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '秒',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// 整体布局：左侧状态/白名单，右侧拦截记录。
class _DashLayout extends StatelessWidget {
  const _DashLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(width: 340, child: _LeftPane()),
        VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _RightPane()),
      ],
    );
  }
}

class _LeftPane extends StatelessWidget {
  const _LeftPane();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _StatusCard(),
        SizedBox(height: 12),
        _WhitelistCard(),
      ],
    );
  }
}

/// 前台 App + 监控开关。
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    final app = controller.frontmost;
    return _SectionCard(
      title: '当前前台应用',
      trailing: Switch(
        value: controller.monitoring,
        activeThumbColor: Colors.green,
        onChanged: (_) => controller.toggleMonitoring(),
      ),
      child: _FrontmostTile(app: app, controller: controller),
    );
  }
}

class _FrontmostTile extends StatelessWidget {
  final RunningAppInfo? app;
  final FocusController controller;

  const _FrontmostTile({required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    final allowed = app == null ||
        controller.whitelist.contains(app!.bundleId);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              (allowed ? Colors.green : Colors.orange).withValues(alpha: 0.12),
          child: Icon(
            allowed ? Icons.check_circle : Icons.warning_amber,
            size: 22,
            color: allowed ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app?.name ?? '未知',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                app?.bundleId ?? '等待前台切换…',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 白名单：运行中 App 列表 + 开关。
class _WhitelistCard extends StatelessWidget {
  const _WhitelistCard();

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    return _SectionCard(
      title: '允许使用的应用（白名单）',
      trailing: IconButton(
        tooltip: '刷新',
        icon: const Icon(Icons.refresh, size: 18),
        onPressed: controller.refreshApps,
      ),
      child: controller.runningApps.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '暂未获取到运行中的应用',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                for (final app in controller.runningApps)
                  _AppRow(
                    app: app,
                    allowed: controller.whitelist.contains(app.bundleId),
                    onChanged: (v) =>
                        controller.toggleWhitelist(app.bundleId, v),
                  ),
              ],
            ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final RunningAppInfo app;
  final bool allowed;
  final ValueChanged<bool> onChanged;

  const _AppRow({
    required this.app,
    required this.allowed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              app.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(
            value: allowed,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// 右侧：实时记录。
class _RightPane extends StatelessWidget {
  const _RightPane();

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActivityCard(controller: controller),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final FocusController controller;

  const _ActivityCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '实时记录',
      child: controller.activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '切入白名单以外的应用后，这里会实时显示拦截过程',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                for (final item in controller.activities.take(50))
                  _ActivityTile(item: item),
              ],
            ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isBlock ? Colors.orange : Colors.green;
    final time =
        '${item.time.hour.toString().padLeft(2, '0')}:'
        '${item.time.minute.toString().padLeft(2, '0')}:'
        '${item.time.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.appName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.detail != null ? '${item.label} · ${item.detail}' : item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (trailing != null) ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}