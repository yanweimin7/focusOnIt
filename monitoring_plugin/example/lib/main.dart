import 'dart:async';

import 'package:flutter/material.dart';
import 'package:monitoring_plugin/monitoring_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plugin = MonitoringPlugin();
  StreamSubscription<MonitorEvent>? _sub;
  String _status = 'unknown';
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _sub = _plugin.stream.listen((e) {
      setState(() {
        final countdown = e.data['countdown'];
        _status = '${e.name}: ${e.data['name']}'
            '${countdown != null ? ' (countdown=${countdown}s)' : ''}';
        if (e.name == 'blocked') _blockedCount++;
      });
    });
    _plugin.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _plugin.stop();
    super.dispose();
  }

  Future<void> _refreshApps() async {
    final apps = await _plugin.getRunningApps();
    final front = await _plugin.getFrontmostApp();
    if (!mounted) return;
    setState(() {
      _status = 'running=${apps.length}, frontmost=${front?.name}. '
          'Events: $_blockedCount blocked';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('monitoring_plugin example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshApps,
                child: const Text('Refresh apps'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}