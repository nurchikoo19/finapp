import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import '../../providers/database_provider.dart';
import '../../theme/tabys_theme.dart';

// ─── Phase enum ───────────────────────────────────────────────────────────────

enum _Phase { work, shortBreak, longBreak }

extension _PhaseX on _Phase {
  String get label => switch (this) {
        _Phase.work => 'Фокус',
        _Phase.shortBreak => 'Короткий перерыв',
        _Phase.longBreak => 'Длинный перерыв',
      };

  int get seconds => switch (this) {
        _Phase.work => 25 * 60,
        _Phase.shortBreak => 5 * 60,
        _Phase.longBreak => 15 * 60,
      };

  Color get color => switch (this) {
        _Phase.work => TColors.gold,
        _Phase.shortBreak => const Color(0xFF4CAF50),
        _Phase.longBreak => const Color(0xFF2196F3),
      };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  _Phase _phase = _Phase.work;
  int _remaining = _Phase.work.seconds;
  bool _running = false;
  int _completed = 0; // completed work sessions
  int? _linkedTaskId;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      setState(() => _running = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _phase.seconds;
    });
  }

  void _setPhase(_Phase p) {
    _timer?.cancel();
    setState(() {
      _phase = p;
      _remaining = p.seconds;
      _running = false;
    });
  }

  void _tick() {
    if (_remaining <= 1) {
      _timer?.cancel();
      _onPhaseComplete();
    } else {
      setState(() => _remaining--);
    }
  }

  Future<void> _onPhaseComplete() async {
    final wasWork = _phase == _Phase.work;
    final newCompleted = wasWork ? _completed + 1 : _completed;

    // Determine next phase
    _Phase next;
    if (wasWork) {
      next = newCompleted % 4 == 0 ? _Phase.longBreak : _Phase.shortBreak;
    } else {
      next = _Phase.work;
    }

    setState(() {
      _completed = newCompleted;
      _phase = next;
      _remaining = next.seconds;
      _running = false;
    });

    // Toast notification
    final n = LocalNotification(
      identifier: 'pomodoro_done',
      title: wasWork ? '🍅 Помодоро завершён!' : '⏰ Перерыв закончился',
      body: wasWork
          ? 'Отличная работа! Время перерыва.'
          : 'Возвращаемся к работе.',
    );
    await n.show();
  }

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      1.0 - (_remaining / _phase.seconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Phase selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _Phase.values.map((p) {
                    final selected = _phase == p;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: selected,
                        selectedColor: p.color.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selected ? p.color : TColors.muted,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        onSelected: (_) => _setPhase(p),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),

                // Circular timer
                _CircularTimer(
                  progress: _progress,
                  color: _phase.color,
                  label: _timeLabel,
                  phase: _phase.label,
                ),
                const SizedBox(height: 32),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Сбросить',
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _toggle,
                      style: FilledButton.styleFrom(
                        backgroundColor: _phase.color,
                        foregroundColor: TColors.ink,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _running ? 'Пауза' : 'Старт',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Pomodoro dots
                _PomodoroDots(completed: _completed),
                const SizedBox(height: 28),

                // Task link
                Builder(builder: (context) {
                  final tasks = ref.watch(filteredTasksProvider);
                  final active = tasks
                      .where((t) =>
                          t.status != 'done' && t.status != 'cancelled')
                      .toList();
                  return DropdownButtonFormField<int?>(
                    value: _linkedTaskId,
                    decoration: InputDecoration(
                      labelText: 'Работаю над задачей',
                      prefixIcon:
                          const Icon(Icons.task_alt_outlined, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('— Без задачи —')),
                      ...active.map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() => _linkedTaskId = v),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Circular timer ───────────────────────────────────────────────────────────

class _CircularTimer extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  final String phase;

  const _CircularTimer({
    required this.progress,
    required this.color,
    required this.label,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
              Text(
                phase,
                style:
                    const TextStyle(fontSize: 13, color: TColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 8.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Pomodoro dots ────────────────────────────────────────────────────────────

class _PomodoroDots extends StatelessWidget {
  final int completed;
  const _PomodoroDots({required this.completed});

  @override
  Widget build(BuildContext context) {
    final inCycle = completed % 4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < inCycle
                ? TColors.gold
                : TColors.gold.withOpacity(0.2),
          ),
        );
      }),
    );
  }
}
