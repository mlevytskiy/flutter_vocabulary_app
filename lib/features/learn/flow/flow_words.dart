import '../../../core/models/word_box.dart';
import '../../../core/models/word_pair.dart';
import '../session/leitner.dart';

/// The pure word rules of the Learn flow (learn-welcome AC-05, AC-06, AC-13;
/// ADR-0002). Nothing here touches the store: the flow notifier hands in the
/// words to learn, their boxes and the card ratings.

/// How many words the cards take at most (AC-05).
const int maxCardWords = 36;

/// A story group's largest size (AC-06).
const int maxGroupSize = 12;

/// The longest other-source tail a full group hands on to the next (AC-06).
const int maxSourceTail = 4;

/// How many groups get a story (AC-06).
const int maxStoryGroups = 3;

/// The answer to "Hard work or easy mode?": it sets the main dialog's length
/// and its practice words (AC-13).
enum FlowMode { easy, hard }

/// The card words (AC-05): up to [maxCardWords] of [rows], in list order, from
/// the first row that is due or new on. When no row is due or new, the
/// [maxCardWords] rows due soonest, in list order among equal dates.
List<WordPair> cardWords(
  List<WordPair> rows,
  List<WordBox> boxes,
  DateTime now,
) {
  final start = rows.indexWhere((row) {
    final box = boxOf(boxes, row);
    return box == null || isDue(box, now);
  });
  if (start >= 0) return rows.skip(start).take(maxCardWords).toList();

  // Every row has a box due later. List.sort is not stable, so ties fall
  // back to the list index.
  final indexed = [
    for (var i = 0; i < rows.length; i++)
      (index: i, row: rows[i], dueAt: boxOf(boxes, rows[i])!.dueAt),
  ]..sort((a, b) {
      final byDate = a.dueAt.compareTo(b.dueAt);
      return byDate != 0 ? byDate : a.index.compareTo(b.index);
    });
  return [for (final e in indexed.take(maxCardWords)) e.row];
}

/// The source a row came from (AC-06): its photo, film or Quizlet set
/// (`sourceId`), or typing.
String sourceKey(WordPair row) {
  final id = row.sourceId;
  return id == null || id.isEmpty ? 'typed' : id;
}

/// The card words cut in order into groups of up to [maxGroupSize] (AC-06,
/// ADR-0002). When a full group ends in a run of up to [maxSourceTail] words
/// from one source other than the word before the run, the run starts the next
/// group instead.
List<List<WordPair>> splitGroups(List<WordPair> words) {
  final groups = <List<WordPair>>[];
  var start = 0;
  while (start < words.length) {
    var end = (start + maxGroupSize).clamp(0, words.length);
    if (end - start == maxGroupSize) {
      final tailKey = sourceKey(words[end - 1]);
      var runStart = end - 1;
      while (runStart > start && sourceKey(words[runStart - 1]) == tailKey) {
        runStart--;
      }
      // A run covering the whole group stays: nothing is before it.
      if (runStart > start && end - runStart <= maxSourceTail) end = runStart;
    }
    groups.add(words.sublist(start, end));
    start = end;
  }
  return groups;
}

/// The groups that get a story: the first [maxStoryGroups] (AC-06).
List<List<WordPair>> storyGroups(List<List<WordPair>> groups) =>
    groups.take(maxStoryGroups).toList();

/// How many learner replies end the main dialog (AC-13): Easy 6, Hard 12.
int dialogReplies(FlowMode mode) => mode == FlowMode.easy ? 6 : 12;

/// The main dialog's practice words (AC-13). Easy takes min(6, ceil(N/2)),
/// at least 4; Hard takes min(12, N); never more than the N card [words].
/// The words rated "I don't remember" today ([dontRemember], row ids) come
/// first, then those rated Hard ([hard]), then the rest, each in list order.
List<WordPair> dialogWords(
  List<WordPair> words, {
  required Set<String> dontRemember,
  required Set<String> hard,
  required FlowMode mode,
}) {
  final count = switch (mode) {
    FlowMode.easy => ((words.length + 1) ~/ 2).clamp(4, 6),
    FlowMode.hard => 12,
  };
  int rank(WordPair w) => dontRemember.contains(w.rowId)
      ? 0
      : hard.contains(w.rowId)
          ? 1
          : 2;
  final ordered = [
    for (final r in const [0, 1, 2])
      for (final w in words)
        if (rank(w) == r) w,
  ];
  return ordered.take(count).toList();
}
