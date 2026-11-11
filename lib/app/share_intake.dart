import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/app/widget_launch.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// A task made from text another app shared ("Read later in ZT Tasks" from
/// ZT Browser, or Android's share sheet): the title is the subject (or the
/// first line that isn't an address), web addresses go into the task's
/// links, and any other text into its description. Nothing is saved until
/// the person taps Save in the editor.
Task sharedTaskDraft({String? subject, String? text}) {
  final body = (text ?? '').trim();
  final urls = <String>[];
  final prose = body.replaceAllMapped(_url, (m) {
    final (url, rest) = _trimUrl(m.group(0)!);
    urls.add(url);
    return rest;
  });
  final lines = <String>[
    for (final line in prose.split('\n'))
      // What an address leaves behind ("see ." or "()") is dropped.
      if (_words(line).isNotEmpty) _words(line),
  ];
  var title = (subject ?? '').trim();
  if (title.isEmpty && lines.isNotEmpty) title = lines.first;
  if (title.isEmpty && urls.isNotEmpty) title = urls.first;
  final rest = [
    for (final l in lines)
      if (l != title) l,
  ].join('\n');
  return Task.create(title: title, description: rest.isEmpty ? null : rest, links: urls.toSet().toList());
}

/// [line] without the bits of punctuation an address leaves behind ("."
/// or "()"). Other symbols stay: "Revenue - expenses = profit" and emoji
/// are the person's own text.
String _words(String line) =>
    line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !_leftover.hasMatch(w)).join(' ');

final _leftover = RegExp(r'''^[().,;:!?\[\]{}'"]+$''');

final _url = RegExp(r'https?://[^\s<>"]+');

/// A web address found in prose, without the sentence's punctuation after
/// it ("see https://x.org/a." or "(https://x.org/a)"); a closing bracket
/// that pairs with one inside the address stays (Wikipedia-style links).
(String, String) _trimUrl(String match) {
  var url = match;
  var cut = '';
  while (url.isNotEmpty) {
    final last = url[url.length - 1];
    final close = {')': '(', ']': '[', '}': '{'}[last];
    if ('.,;:!?\'"'.contains(last) || (close != null && close.allMatches(url).length < last.allMatches(url).length)) {
      cut = last + cut;
      url = url.substring(0, url.length - 1);
    } else {
      break;
    }
  }
  return (url, cut);
}

/// Text shared to ZT Tasks, from MainActivity over `zt_tasks/share`: on a
/// cold start it waits there to be taken, later it's pushed. Each one opens
/// the task editor (once the tasks are open) through [widgetLaunchProvider].
class ShareIntake {
  ShareIntake(this._ref);

  final WidgetRef _ref;
  static const _channel = MethodChannel('zt_tasks/share');

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _handle(call.arguments);
    });
    try {
      _handle(await _channel.invokeMethod<Object?>('take'));
    } on Object {
      // Not on Android: nothing is shared.
    }
  }

  void _handle(Object? args) {
    if (args is! Map) return;
    final text = args['text'] as String?;
    final subject = args['subject'] as String?;
    if ((text ?? '').trim().isEmpty && (subject ?? '').trim().isEmpty) return;
    _ref
        .read(widgetLaunchProvider.notifier)
        .set(
          Uri(
            scheme: 'zerotrusttasks',
            host: 'shared',
            queryParameters: <String, String>{if (text != null) 'text': text, if (subject != null) 'subject': subject},
          ),
        );
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
