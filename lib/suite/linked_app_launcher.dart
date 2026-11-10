import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';

const _channel = MethodChannel('zt_tasks/apps');

/// Opens ZT Notes or ZT Contacts, or its store page when it isn't
/// installed. Returns whether the app itself opened.
Future<bool> openLinkedApp(LinkedApp app) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      return await _channel.invokeMethod<bool>('open', {'package': app.androidPackage}) ?? false;
    } on Object {
      // Fall through to the store link.
    }
  }
  await launchUrl(
    Uri.https('play.google.com', '/store/apps/details', {'id': app.androidPackage}),
    mode: LaunchMode.externalApplication,
  );
  return false;
}
