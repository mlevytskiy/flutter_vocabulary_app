import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one source of randomness for exercises (learn-pick-the-answer S-27).
/// Read once per notifier build; tests override it with `Random(seed)`.
final exerciseRandomProvider = Provider<Random>((ref) => Random());
