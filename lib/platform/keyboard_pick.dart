import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ZT Keyboard's "Insert from ZT apps" key opened Tasks so the user can pick
/// a task's title, due date, checklist or links to type. The Android side
/// has already checked that the asking app is signed with this app's own
/// key (see `TextPick.kt`).
class KeyboardPick {
  const KeyboardPick._();
  static const _channel = MethodChannel('zt_tasks/text_pick');

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Whether this screen was opened by the keyboard for a pick.
  static Future<bool> requested() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('isPick') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Answers the keyboard with the picked [text] (null: nothing) and closes
  /// the pick screen.
  static Future<void> finish(String? text) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('finish', {'text': text});
    } on MissingPluginException {
      // Not running on the Android app (tests).
    } on PlatformException {
      // Nothing to answer.
    }
  }
}
