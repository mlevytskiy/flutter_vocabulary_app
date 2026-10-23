import 'dart:math';

/// The three rungs of the word ladder: a word meets step 1 pages, then
/// step 2, then step 3 (learn-redesign AC-08).
enum Rung {
  meet,
  practise,
  use;

  /// The exercise step this rung plays: 1, 2 or 3.
  int get step => index + 1;
}

/// The pure word-ladder queue of a learning session (learn-redesign
/// ADR-0004; AC-08, AC-09, AC-14).
///
/// Each word starts on [Rung.meet]. One right page moves it up one rung and to
/// the end of the pending order; a right page on [Rung.use] passes it (it
/// leaves the queue). A miss moves it one rung down (staying on Meet), sets
/// its miss flag and puts it back so that it is shown [reinsertDistance]
/// pages later, or at the end when fewer pages remain. The same word is never
/// returned twice in a row while another word is pending. Due words come
/// first in the initial order; each class is shuffled with the given
/// [Random], so a seeded one makes the queue deterministic.
///
/// [record] takes any pending word, not only the one [next] returned, so a
/// board page can record each of its words.
class LadderQueue {
  /// How many pages later a missed word comes back (AC-09).
  static const defaultReinsertDistance = 3;

  LadderQueue(
    List<String> rowIds, {
    Set<String> due = const {},
    required Random random,
    this.reinsertDistance = defaultReinsertDistance,
  }) : assert(reinsertDistance >= 1) {
    final unique = rowIds.toSet().toList();
    final dueFirst = [
      for (final id in unique)
        if (due.contains(id)) id
    ]..shuffle(random);
    final rest = [
      for (final id in unique)
        if (!due.contains(id)) id
    ]..shuffle(random);
    _pending.addAll([...dueFirst, ...rest]);
    for (final id in unique) {
      _rungs[id] = Rung.meet;
    }
  }

  /// How many pages later a missed word comes back.
  final int reinsertDistance;

  final _pending = <String>[];
  final _rungs = <String, Rung>{};
  final _missed = <String>{};
  final _passed = <String>{};
  String? _lastRecorded;
  int _answered = 0;

  /// The word and rung to show next, or null when every word has passed.
  ///
  /// Calling it again without a [record] in between returns the same page.
  ({String rowId, Rung rung})? next() {
    if (_pending.isEmpty) return null;
    var id = _pending.first;
    if (id == _lastRecorded && _pending.length > 1) id = _pending[1];
    return (rowId: id, rung: _rungs[id]!);
  }

  /// Records one answered page of [rowId]: right moves it up a rung (passing
  /// it after Use), a miss moves it down a rung and reinserts it.
  void record(String rowId, bool right) {
    final rung = _rungs[rowId];
    if (rung == null) {
      throw ArgumentError.value(rowId, 'rowId', 'not in this queue');
    }
    if (_passed.contains(rowId)) {
      throw StateError('$rowId has already passed its Use page');
    }
    _pending.remove(rowId);
    _answered++;
    _lastRecorded = rowId;
    if (right) {
      if (rung == Rung.use) {
        _passed.add(rowId);
        return;
      }
      _rungs[rowId] = Rung.values[rung.index + 1];
      _pending.add(rowId);
    } else {
      _missed.add(rowId);
      if (rung != Rung.meet) _rungs[rowId] = Rung.values[rung.index - 1];
      _pending.insert(min(reinsertDistance - 1, _pending.length), rowId);
    }
  }

  /// True once every word has passed a Use page.
  bool get isDone => _pending.isEmpty;

  /// Whether [rowId] had any miss in this session.
  bool missed(String rowId) => _missed.contains(rowId);

  /// The rung [rowId] stands on ([Rung.use] once passed).
  Rung rungOf(String rowId) => _rungs[rowId]!;

  /// Whether [rowId] has passed its Use page.
  bool passed(String rowId) => _passed.contains(rowId);

  /// How many pages have been recorded.
  int get answered => _answered;

  /// How many words still wait for a page.
  int get pendingCount => _pending.length;

  /// [answered] plus the rungs every pending word still has to climb: the M
  /// of "page N of M" (AC-08). It grows on a miss.
  int get estimatedTotal =>
      _answered +
      _pending.fold(
          0, (sum, id) => sum + Rung.values.length - _rungs[id]!.index);
}
