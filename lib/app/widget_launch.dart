import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:zero_trust_tasks/core/services/home_widget_service.dart';

/// A tap on the home-screen widget waiting to be acted on once the tasks
/// are open: `zerotrusttasks://new-task` or `zerotrusttasks://task?id=…`.
class WidgetLaunch extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  void set(Uri? uri) => state = uri;

  Uri? take() {
    final uri = state;
    state = null;
    return uri;
  }
}

final widgetLaunchProvider = NotifierProvider<WidgetLaunch, Uri?>(WidgetLaunch.new);

/// Feeds widget taps (cold start and while running) into
/// [widgetLaunchProvider].
class WidgetLaunchListener {
  WidgetLaunchListener(this._ref);

  final WidgetRef _ref;
  StreamSubscription<Uri?>? _sub;

  Future<void> start() async {
    if (!HomeWidgetService.isSupported) return;
    try {
      _handle(await HomeWidget.initiallyLaunchedFromHomeWidget());
      _sub = HomeWidget.widgetClicked.listen(_handle);
    } on Object {
      // No widget support: nothing to listen to.
    }
  }

  void _handle(Uri? uri) {
    if (uri == null || uri.host == 'open') return;
    _ref.read(widgetLaunchProvider.notifier).set(uri);
  }

  void dispose() => _sub?.cancel();
}
