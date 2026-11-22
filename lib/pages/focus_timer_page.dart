import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/suite/zt_time.dart';

/// A focus timer on one task (T-6): pick a length, start, pause or stop.
/// The minutes add up on the task, and the stretch can be logged in
/// ZT Time with one tap, linked back to the task.
class FocusTimerPage extends ConsumerStatefulWidget {
  const FocusTimerPage({super.key, required this.task, this.clock = DateTime.now});

  final Task task;

  /// For tests; the current time otherwise.
  final DateTime Function() clock;

  static const lengths = [15, 25, 50];

  @override
  ConsumerState<FocusTimerPage> createState() => _FocusTimerPageState();
}

enum _Phase { ready, running, paused, finished }

class _FocusTimerPageState extends ConsumerState<FocusTimerPage> {
  int _minutes = 25;
  _Phase _phase = _Phase.ready;
  DateTime? _startedAt;
  DateTime? _endedAt;

  /// Time spent focused before the latest resume.
  Duration _banked = Duration.zero;
  DateTime? _resumedAt;
  Timer? _tick;
  bool _logged = false;

  Duration get _length => Duration(minutes: _minutes);

  Duration get _focused {
    final running = _phase == _Phase.running && _resumedAt != null ? widget.clock().difference(_resumedAt!) : Duration.zero;
    final total = _banked + running;
    return total > _length ? _length : total;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    final now = widget.clock();
    setState(() {
      _phase = _Phase.running;
      _startedAt = now;
      _resumedAt = now;
      _banked = Duration.zero;
      _logged = false;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    if (_focused >= _length) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _pause() => setState(() {
        _banked = _focused;
        _resumedAt = null;
        _phase = _Phase.paused;
      });

  void _resume() => setState(() {
        _resumedAt = widget.clock();
        _phase = _Phase.running;
      });

  Future<void> _finish() async {
    _tick?.cancel();
    final focused = _focused;
    setState(() {
      _banked = focused;
      _resumedAt = null;
      _endedAt = widget.clock();
      _phase = _Phase.finished;
    });
    unawaited(HapticFeedback.mediumImpact());
    final minutes = focused.inMinutes;
    if (minutes <= 0) return;
    final manager = ref.read(taskManagerProvider);
    final current = manager.tasks.where((t) => t.id == widget.task.id).firstOrNull ?? widget.task;
    await manager.updateTask(current.withFocusMinutes(current.focusMinutes + minutes));
  }

  Future<void> _logInTime() async {
    final start = _startedAt;
    final end = _endedAt;
    if (start == null || end == null) return;
    final l10n = context.l10n;
    final answer = await ZtTime.track(widget.task, start: start, end: end);
    if (!mounted) return;
    switch (answer) {
      case TimeHandOver.done:
        setState(() => _logged = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.focusLoggedInTime)));
      case TimeHandOver.cancelled:
        break;
      case TimeHandOver.missing:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ztTimeNotInstalled),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(label: l10n.getZtTime, onPressed: ZtTime.openDownloadPage),
          ),
        );
    }
  }

  String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final manager = ref.watch(taskManagerProvider);
    final task = manager.tasks.where((t) => t.id == widget.task.id).firstOrNull ?? widget.task;
    final left = _length - _focused;
    final progress = _phase == _Phase.ready ? 0.0 : _focused.inMilliseconds / _length.inMilliseconds;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.focusTimer)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(task.title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (task.focusMinutes > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.focusedSoFar(task.focusMinutes),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: SizedBox.square(
                dimension: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(value: progress, strokeWidth: 10),
                    Center(
                      child: Text(
                        _phase == _Phase.finished ? _clock(_focused) : _clock(left),
                        style: theme.textTheme.displayMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_phase == _Phase.ready) ...[
              Center(
                child: SegmentedButton<int>(
                  segments: [
                    for (final m in FocusTimerPage.lengths) ButtonSegment(value: m, label: Text(l10n.minutesShort(m))),
                  ],
                  selected: {_minutes},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _minutes = s.single),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: Text(l10n.focusStart)),
              const SizedBox(height: 12),
              Text(l10n.focusKeepOpenHint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (_phase == _Phase.running || _phase == _Phase.paused) ...[
              FilledButton.icon(
                onPressed: _phase == _Phase.running ? _pause : _resume,
                icon: Icon(_phase == _Phase.running ? Icons.pause : Icons.play_arrow),
                label: Text(_phase == _Phase.running ? l10n.focusPause : l10n.focusResume),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _finish, icon: const Icon(Icons.stop), label: Text(l10n.focusStop)),
            ],
            if (_phase == _Phase.finished) ...[
              Text(
                l10n.focusDone(_focused.inMinutes),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_focused.inMinutes > 0)
                FilledButton.icon(
                  onPressed: _logged ? null : _logInTime,
                  icon: Icon(_logged ? Icons.check : Icons.timer_outlined),
                  label: Text(_logged ? l10n.focusLoggedInTime : l10n.logInZtTime),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() {
                  _phase = _Phase.ready;
                  _banked = Duration.zero;
                  _startedAt = null;
                  _endedAt = null;
                }),
                child: Text(l10n.focusAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
