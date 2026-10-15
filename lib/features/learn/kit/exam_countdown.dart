import 'dart:async';

import 'package:flutter/material.dart';

/// The time left as "m:ss" (90 → "1:30", 30 → "0:30") (S-61).
String countdownText(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// An exam's countdown (learn-explain-to-friend S-61, D-40): shows the time
/// left, counts down once a second and calls [onZero] exactly once at 0. No
/// pause; the caller stops it by removing it from the tree. Time the OS keeps
/// the app suspended is not caught up.
class ExamCountdown extends StatefulWidget {
  const ExamCountdown({super.key, required this.seconds, required this.onZero});

  final int seconds;
  final VoidCallback onZero;

  @override
  State<ExamCountdown> createState() => _ExamCountdownState();
}

class _ExamCountdownState extends State<ExamCountdown> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_left <= 0) return;
    setState(() => _left--);
    if (_left == 0) {
      _timer?.cancel();
      widget.onZero();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(countdownText(_left), key: const ValueKey('exam-countdown'));
}
