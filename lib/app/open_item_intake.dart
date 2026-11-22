import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/app/widget_launch.dart';

/// A task another Zero-Trust app asked to open (ZT Time's link back to the
/// task an entry was tracked for: bz.zerotrust.action.OPEN_ITEM). Waits in
/// MainActivity over `zt_tasks/open_item` on a cold start, is pushed later,
/// and opens like a widget tap once the tasks are unlocked. An unknown id
/// just leaves the app open.
class OpenItemIntake {
  OpenItemIntake(this._ref);

  final WidgetRef _ref;
  static const _channel = MethodChannel('zt_tasks/open_item');

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _handle(call.arguments);
    });
    try {
      _handle(await _channel.invokeMethod<Object?>('take'));
    } on Object {
      // Not on Android: nothing to open.
    }
  }

  void _handle(Object? id) {
    if (id is! String || id.isEmpty) return;
    _ref
        .read(widgetLaunchProvider.notifier)
        .set(Uri(scheme: 'zerotrusttasks', host: 'task', queryParameters: {'id': id}));
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
