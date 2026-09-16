import 'package:flutter_test/flutter_test.dart';

import 'package:focus_on_it/focus_controller.dart';

void main() {
  group('ActivityItem', () {
    test('label maps known events and appends detail', () {
      final item = ActivityItem(
        time: DateTime(2026, 1, 1),
        event: 'blocked',
        appName: 'Safari',
        detail: '5 秒后将终止',
      );
      expect(item.label, '拦截');
      expect(item.isBlock, isTrue);
    });

    test('non-block event is not marked as block', () {
      final item = ActivityItem(
        time: DateTime(2026, 1, 1),
        event: 'appActivated',
        appName: 'Code',
      );
      expect(item.label, '激活');
      expect(item.isBlock, isFalse);
    });
  });
}