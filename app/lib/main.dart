import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:monitoring_plugin/monitoring_plugin.dart';

import 'focus_controller.dart';

// ---------------------------------------------------------------------------
// 主题色（深色专注风）
// ---------------------------------------------------------------------------
const kBg = Color(0xFF0B0F1A);
const kSurface = Color(0xFF121826);
const kSurfaceHi = Color(0xFF1A2233);
const kBorder = Color(0xFF242E42);
const kText = Color(0xFFE7EAF1);
const kTextMuted = Color(0xFF98A2B5);
const kTextFaint = Color(0xFF6B7689);
const kTeal = Color(0xFF2DD4BF);
const kTealDeep = Color(0xFF14B8A6);
const kGreen = Color(0xFF34D399);
const kAmber = Color(0xFFFBBF24);
const kRed = Color(0xFFF87171);

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
      theme: _buildTheme(),
      home: _Scope(
        controller: _controller,
        child: const HomePage(),
      ),
    );
  }
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kTealDeep,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kTeal,
    onPrimary: const Color(0xFF04211D),
    secondary: kTealDeep,
    surface: kSurface,
    onSurface: kText,
    surfaceContainerHighest: kSurfaceHi,
    outline: kBorder,
    error: kRed,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    fontFamily: '.SF Pro Display',
    cardTheme: const CardThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : kTextMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kTeal : kBorder,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: kBorder),
    iconTheme: const IconThemeData(color: kTextMuted),
    textSelectionTheme: TextSelectionThemeData(cursorColor: kTeal, selectionColor: kTeal.withValues(alpha: 0.3)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: const TextStyle(color: kTextFaint, fontSize: 13),
      labelStyle: const TextStyle(color: kTextMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kTeal, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kTeal,
        foregroundColor: const Color(0xFF04211D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kTeal),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurfaceHi,
      contentTextStyle: const TextStyle(color: kText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kBorder)),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: controller.ready
                ? const _DashLayout()
                : const Center(child: CircularProgressIndicator(color: kTeal)),
          ),
        ],
      ),
    );
  }
}

/// 顶部：品牌 + 监控状态 + 锁 + 收缩。
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kTeal, kTealDeep],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.center_focus_strong, color: Color(0xFF04211D), size: 17),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'FocusOnIt',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText, letterSpacing: 0.2),
              ),
              Text('macOS 专注守护', style: TextStyle(fontSize: 10.5, color: kTextFaint)),
            ],
          ),
          const Spacer(),
          _StatusPill(monitoring: controller.monitoring),
          const SizedBox(width: 6),
          _LockButton(controller: controller),
          Tooltip(
            message: '收缩到菜单栏',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 22, color: kTextMuted),
                onPressed: controller.collapseToMenuBar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool monitoring;

  const _StatusPill({required this.monitoring});

  @override
  Widget build(BuildContext context) {
    final color = monitoring ? kGreen : kTextFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            monitoring ? '监控中' : '已暂停',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
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
        SizedBox(width: 330, child: _LeftPane()),
        VerticalDivider(width: 1, thickness: 1, color: kBorder),
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
      padding: const EdgeInsets.all(14),
      children: const [
        _StatusCard(),
        SizedBox(height: 10),
        _StatStrip(),
        SizedBox(height: 10),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LockButton(controller: controller),
          const SizedBox(width: 6),
          Switch(
            value: controller.monitoring,
            onChanged: (_) => _guardedChange(
              context,
              controller,
              controller.toggleMonitoring,
            ),
          ),
        ],
      ),
      child: _FrontmostTile(app: app, controller: controller),
    );
  }
}

/// 密码锁按钮：未设置 → 弹设置；已设置未解锁 → 弹输入；已解锁 → 点击锁定。
class _LockButton extends StatelessWidget {
  final FocusController controller;

  const _LockButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: !controller.passwordSet
            ? '设置保护密码'
            : (controller.isUnlocked
                ? '已解锁（点击锁定）'
                : (controller.biometricAvailable ? '指纹或密码解锁' : '输入密码解锁')),
        icon: Icon(
          !controller.passwordSet
              ? Icons.lock_outline
              : (controller.isUnlocked ? Icons.lock_open : Icons.lock),
          size: 18,
          color: !controller.passwordSet
              ? kTextFaint
              : (controller.isUnlocked ? kTeal : kAmber),
        ),
        onPressed: () async {
          if (!controller.passwordSet) {
            await _promptSetPassword(context, controller);
          } else if (controller.isUnlocked) {
            controller.lock();
          } else {
            await _promptUnlock(context, controller, showSnack: true);
          }
        },
      ),
    );
  }
}

/// 密码保护门槛：白名单 / 监控开关等敏感操作统一走这里。
Future<void> _guardedChange(
  BuildContext context,
  FocusController controller,
  Future<void> Function() action,
) async {
  if (controller.passwordSet && !controller.isUnlocked) {
    final ok = await _promptUnlock(context, controller, showSnack: false);
    if (ok != true) return;
  }
  await action();
}

Future<bool?> _promptUnlock(
  BuildContext context,
  FocusController controller, {
  bool showSnack = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(
      controller: controller,
      mode: _PasswordMode.unlock,
      showSnack: showSnack,
    ),
  );
}

Future<void> _promptSetPassword(
  BuildContext context,
  FocusController controller,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(
      controller: controller,
      mode: _PasswordMode.set,
    ),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保护密码已设置')),
    );
  }
}

enum _PasswordMode { set, unlock }

class _PasswordDialog extends StatefulWidget {
  final FocusController controller;
  final _PasswordMode mode;
  final bool showSnack;

  const _PasswordDialog({
    required this.controller,
    required this.mode,
    this.showSnack = false,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  final bool _obscure = true;
  bool _submitting = false;
  bool _biometricBusy = false;
  String? _error;

  bool get isSet => widget.mode == _PasswordMode.set;

  /// 解锁模式下指纹可用才展示指纹入口。
  bool get _biometricReady =>
      !isSet && widget.controller.biometricAvailable;

  @override
  void initState() {
    super.initState();
    if (_biometricReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitBiometric());
    }
  }

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Touch ID 解锁；取消不提示，其余失败给出原因。
  Future<void> _submitBiometric() async {
    if (_biometricBusy || _submitting) return;
    setState(() {
      _biometricBusy = true;
      _error = null;
    });
    final result = await widget.controller.unlockWithBiometrics();
    if (!mounted) return;
    if (result.ok) {
      if (widget.showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已解锁，1 分钟内可修改设置')),
        );
      }
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _biometricBusy = false;
      _error = result.code == 'userCancel' ? null : _biometricErrorText(result.code);
    });
  }

  String _biometricErrorText(String code) {
    switch (code) {
      case 'authenticationFailed':
        return '指纹不匹配，可重试或输入密码';
      case 'lockout':
        return '指纹已被锁定，请改用密码';
      case 'notEnrolled':
        return '尚未录入指纹，请先在系统设置中录入';
      case 'notAvailable':
        return '指纹识别不可用，请输入密码';
      default:
        return '指纹验证失败，请输入密码';
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    final pwd = _pwd.text;

    if (isSet) {
      if (pwd.length < 4) {
        setState(() {
          _error = '密码至少 4 位';
          _submitting = false;
        });
        return;
      }
      if (pwd != _confirm.text) {
        setState(() {
          _error = '两次输入的密码不一致';
          _submitting = false;
        });
        return;
      }
      await widget.controller.setPassword(pwd);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final ok = await widget.controller.unlock(pwd);
    if (!mounted) return;
    if (ok) {
      if (widget.showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已解锁，1 分钟内可修改设置')),
        );
      }
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = '密码错误';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: kTeal, size: 20),
          const SizedBox(width: 8),
          Text(isSet ? '设置保护密码' : '输入密码'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_biometricReady) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_biometricBusy || _submitting) ? null : _submitBiometric,
                icon: _biometricBusy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kTeal),
                      )
                    : const Icon(Icons.fingerprint, size: 19),
                label: Text(_biometricBusy ? '等待指纹验证…' : '使用 Touch ID 解锁'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTeal,
                  side: const BorderSide(color: kBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('或输入密码', style: TextStyle(fontSize: 11, color: kTextFaint)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _pwd,
            obscureText: _obscure,
            autofocus: !_biometricReady,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: '密码'),
          ),
          if (isSet) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: kRed, fontSize: 13),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(isSet ? '设置' : '解锁'),
        ),
      ],
    );
  }
}

/// 前台应用的大图标展示。
class _FrontmostTile extends StatelessWidget {
  final RunningAppInfo? app;
  final FocusController controller;

  const _FrontmostTile({required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasApp = app != null;
    final allowed =
        hasApp && controller.whitelist.contains(app!.bundleId);
    final blockColor = allowed ? kGreen : kAmber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AppIcon(app: app, size: 44, radius: 11),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app?.name ?? '未知应用',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app?.bundleId ?? '等待前台切换…',
                    style: const TextStyle(fontSize: 11, color: kTextFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasApp)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: blockColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(allowed ? Icons.check_circle : Icons.warning_amber,
                        size: 13, color: blockColor),
                    const SizedBox(width: 4),
                    Text(
                      allowed ? '允许' : '拦截',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: blockColor),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (allowed ? kGreen : kAmber).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (allowed ? kGreen : kAmber).withValues(alpha: 0.25)),
          ),
          child: Text(
            allowed
                ? '该应用在白名单内，可正常使用'
                : '切换到此应用将被立即终止',
            style: TextStyle(fontSize: 11.5, color: allowed ? kText : kTextMuted),
          ),
        ),
      ],
    );
  }
}

/// 三枚统计卡。
class _StatStrip extends StatelessWidget {
  const _StatStrip();

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    final today = DateTime.now();
    final blockedToday = controller.activities
        .where((a) => a.isBlock && a.time.year == today.year && a.time.month == today.month && a.time.day == today.day)
        .length;
    return Row(
      children: [
        _StatBox(value: '${controller.whitelist.length}', label: '白名单'),
        const SizedBox(width: 10),
        _StatBox(value: '$blockedToday', label: '今日拦截'),
        const SizedBox(width: 10),
        _StatBox(value: '${controller.runningApps.length}', label: '已装应用'),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTeal)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: kTextFaint)),
          ],
        ),
      ),
    );
  }
}

/// 白名单：可搜索的应用列表 + 开关。
class _WhitelistCard extends StatefulWidget {
  const _WhitelistCard();

  @override
  State<_WhitelistCard> createState() => _WhitelistCardState();
}

class _WhitelistCardState extends State<_WhitelistCard> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _Scope.of(context);
    final query = _query.trim().toLowerCase();
    final apps = query.isEmpty
        ? controller.sortedApps
        : controller.sortedApps
            .where((a) => a.name.toLowerCase().contains(query) || a.bundleId.toLowerCase().contains(query))
            .toList();

    return _SectionCard(
      title: '允许使用的应用',
      trailing: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          tooltip: '刷新应用列表',
          icon: const Icon(Icons.refresh, size: 17),
          color: kTextMuted,
          onPressed: controller.refreshApps,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '搜索应用…',
              prefixIcon: Icon(Icons.search, size: 16),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                query.isEmpty ? '暂未获取到应用列表' : '没有匹配的应用',
                style: const TextStyle(fontSize: 12.5, color: kTextFaint),
              ),
            )
          else
            ...apps.map((app) => _AppRow(
                  app: app,
                  allowed: controller.whitelist.contains(app.bundleId),
                  onChanged: (v) => _guardedChange(
                    context,
                    controller,
                    () => controller.toggleWhitelist(app.bundleId, v),
                  ),
                )),
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
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: allowed ? kTeal.withValues(alpha: 0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allowed ? kTeal.withValues(alpha: 0.25) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          _AppIcon(app: app, size: 26, radius: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (app.pid > 0)
                  Text(
                    'PID ${app.pid}',
                    style: const TextStyle(fontSize: 10, color: kTextFaint),
                  ),
              ],
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
      padding: const EdgeInsets.all(14),
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
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.bolt_outlined, size: 28, color: kTextFaint.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                  const Text(
                    '切入白名单以外的应用后，这里会实时显示拦截过程',
                    style: TextStyle(fontSize: 12.5, color: kTextFaint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.activities.length > 50)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('仅显示最近 50 条',
                        style: TextStyle(fontSize: 10.5, color: kTextFaint)),
                  ),
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

  (Color, IconData) get _spec {
    if (item.isBlock) return (kRed, Icons.block);
    return (kTeal, Icons.center_focus_strong);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _spec;
    final time =
        '${item.time.hour.toString().padLeft(2, '0')}:'
        '${item.time.minute.toString().padLeft(2, '0')}:'
        '${item.time.second.toString().padLeft(2, '0')}';
    final detail = item.detail != null ? '${item.label} · ${item.detail}' : item.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.appName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: kTextFaint,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              detail,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextMuted,
                  letterSpacing: 0.3,
                ),
              ),
              if (trailing != null) ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// App 图标：有真实 PNG 用它，否则用首字母 + 主题色兜底。
class _AppIcon extends StatelessWidget {
  final RunningAppInfo? app;
  final double size;
  final double radius;

  const _AppIcon({required this.app, this.size = 32, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = app?.icon;
    if (bytes != null || app == null) {
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
        );
      }
      return _placeholder(size, radius);
    }

    final name = app!.name.trim();
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final hue = (app!.bundleId.hashCode % 360).abs().toDouble();
    final bg = HSLColor.fromAHSL(0.16, hue, 0.55, 0.45).toColor();
    final fg = HSLColor.fromAHSL(0.92, hue, 0.55, 0.42).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _placeholder(double size, double radius) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kSurfaceHi,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.question_mark, size: size * 0.5, color: kTextFaint),
    );
  }
}