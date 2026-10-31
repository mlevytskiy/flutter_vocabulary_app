import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The English levels the warm-up intro offers, in tap order (learn-warm-up-v2 AC-01).
const learnerLevels = <String>[
  'Beginner',
  'Elementary',
  'Intermediate',
  'Upper-intermediate',
  'Advanced',
  'Not sure',
];

/// Longest goal / daily-context text (AC-04).
const learnerTextMax = 80;

/// What the app remembers about the learner, plus the warm-up's round and
/// counters (learn-warm-up-v2, ADR-0001). Stays on the phone.
class LearnerProfile {
  const LearnerProfile({
    this.level,
    this.goal,
    this.daily,
    this.round = const [],
    this.grammarCounter = 0,
    this.talksCounter = 0,
  });

  /// One of [learnerLevels], or null (the intro asks it).
  final String? level;

  /// A fixed-list tap or the learner's own words (at most [learnerTextMax]).
  final String? goal;
  final String? daily;

  /// Main questions still to ask in this round of three; the first comes next.
  final List<String> round;

  /// Finished warm-ups since the grammar question was last answered.
  final int grammarCounter;

  /// Talks that reached results since the last 👍/👎 question.
  final int talksCounter;

  LearnerProfile copyWith({
    String? Function()? level,
    String? Function()? goal,
    String? Function()? daily,
    List<String>? round,
    int? grammarCounter,
    int? talksCounter,
  }) =>
      LearnerProfile(
        level: level != null ? level() : this.level,
        goal: goal != null ? goal() : this.goal,
        daily: daily != null ? daily() : this.daily,
        round: round ?? this.round,
        grammarCounter: grammarCounter ?? this.grammarCounter,
        talksCounter: talksCounter ?? this.talksCounter,
      );

  Map<String, dynamic> toJson() => {
        'v': LearnerProfileStore.version,
        if (level != null) 'level': level,
        if (goal != null) 'goal': goal,
        if (daily != null) 'daily': daily,
        'round': round,
        'grammar': grammarCounter,
        'talks': talksCounter,
      };
}

/// Reads and writes the [LearnerProfile] as one versioned JSON value in
/// preferences. Never throws: a missing or bad value reads as empty.
class LearnerProfileStore {
  static const key = 'learner_profile';
  static const version = 1;

  Future<LearnerProfile> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const LearnerProfile();
      final m = jsonDecode(raw);
      if (m is! Map || m['v'] != version) return const LearnerProfile();
      String? text(String k) {
        final v = m[k];
        return v is String && v.isNotEmpty ? v : null;
      }

      final level = m['level'];
      final round = m['round'];
      final grammar = m['grammar'];
      final talks = m['talks'];
      return LearnerProfile(
        level: level is String && learnerLevels.contains(level) ? level : null,
        goal: text('goal'),
        daily: text('daily'),
        round: round is List ? round.whereType<String>().toList() : const [],
        grammarCounter: grammar is int && grammar >= 0 ? grammar : 0,
        talksCounter: talks is int && talks >= 0 ? talks : 0,
      );
    } catch (_) {
      return const LearnerProfile();
    }
  }

  Future<LearnerProfile> _change(LearnerProfile Function(LearnerProfile) f) async {
    final next = f(await read());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(next.toJson()));
    } catch (_) {}
    return next;
  }

  /// Sets the level (a tap or Learn settings); null clears it. Round and
  /// counters stay (AC-03).
  Future<void> setLevel(String? level) => _change((p) => p.copyWith(level: () => level));

  /// Sets or clears the goal as the learner chose it (Learn settings, a tap).
  Future<void> setGoal(String? goal) => _change((p) => p.copyWith(goal: () => _clean(goal)));

  Future<void> setDaily(String? daily) => _change((p) => p.copyWith(daily: () => _clean(daily)));

  /// The warm-up's own-words answer: empty or over [learnerTextMax] is dropped, and
  /// a 1-2 character answer is saved only into an empty field (AC-04).
  Future<void> saveGoalAnswer(String text) => _change((p) {
        final t = _answer(text, p.goal);
        return t == null ? p : p.copyWith(goal: () => t);
      });

  Future<void> saveDailyAnswer(String text) => _change((p) {
        final t = _answer(text, p.daily);
        return t == null ? p : p.copyWith(daily: () => t);
      });

  Future<void> setRound(List<String> round) => _change((p) => p.copyWith(round: List.of(round)));

  /// An answered main question leaves the round (AC-03).
  Future<void> markMainAnswered(String id) =>
      _change((p) => p.copyWith(round: p.round.where((q) => q != id).toList()));

  Future<void> setGrammarCounter(int n) => _change((p) => p.copyWith(grammarCounter: n));

  Future<void> setTalksCounter(int n) => _change((p) => p.copyWith(talksCounter: n));

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty || t.length > learnerTextMax ? null : t;
  }

  static String? _answer(String text, String? current) {
    final t = _clean(text);
    if (t == null) return null;
    if (t.length <= 2 && current != null) return null;
    return t;
  }
}
