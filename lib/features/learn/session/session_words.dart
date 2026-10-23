import '../../../core/models/word_collection.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/story/word_grouping.dart' show groupWords, wordsToLearn;
import '../kit/split_rounds.dart';
import 'leitner.dart';

/// The pure word picker of a learning session or a talk (learn-redesign
/// AC-05, AC-06, AC-07, AC-14; ADR-0005). Nothing here touches the store or
/// the preferences: the caller hands in the split choice, the words-per-session
/// setting and the last played group index.

/// From this many words to learn the Learn sheet offers the split (AC-05);
/// below it a session takes every word (AC-06).
const int splitShowsAt = 20;

/// A session group's largest size (AC-06, ADR-0005). The smallest, 7, follows
/// from [splitRounds]' balanced cut for 14 or more words.
const int _maxSessionGroup = 12;

/// The session groups (ADR-0005): the words to learn in AI-group order — each
/// stored group's words in group order, then the words in no group (waiting
/// words) in row order; plain row order while there are no groups — each word
/// once, cut by [splitRounds] into parts of 7–12. Every part holds 7–12 words
/// for 14 or more words to learn.
List<List<WordPair>> sessionGroups(WordCollection c) {
  final seen = <String>{};
  final ordered = <WordPair>[
    for (final g in c.groups)
      for (final w in groupWords(c, g))
        if (seen.add(w.rowId)) w,
    for (final w in wordsToLearn(c))
      if (seen.add(w.rowId)) w,
  ];
  // min 1, not 7: splitRounds asserts max ≥ 2 × min − 1 (13 words cannot be
  // cut into 7–12). Its balanced cut keeps every part at 7 or more for 14+
  // words, and a split is only offered from 20.
  return splitRounds(ordered, min: 1, max: _maxSessionGroup);
}

/// The words a session takes, with the session group they come from.
class SessionPick {
  final List<WordPair> words;

  /// The session group's 0-based index; null when the session is not split.
  final int? groupIndex;

  /// How many session groups there are; 0 when the session is not split.
  final int groupCount;

  /// Row ids of [words] that are due at the pick (AC-14).
  final Set<String> dueRowIds;

  /// Row ids of [words] that have no box yet.
  final Set<String> newRowIds;

  const SessionPick({
    required this.words,
    this.groupIndex,
    this.groupCount = 0,
    required this.dueRowIds,
    required this.newRowIds,
  });
}

/// Picks a session's words (AC-06, AC-07, AC-14).
///
/// [rowIds] given (Practise N shaky) → exactly those rows, in row order. Else
/// under [splitShowsAt] words to learn → all of them. Else with [split] → one
/// session group: the first (in group order) holding a due word, else the first
/// holding a new word, else the one after [lastGroup] (the first when null,
/// wrapping). [skipGroup] ("Next group") is left out of the first two rules and
/// the third starts after it. Else → due words, then new words, then the others
/// (each in row order), at most [wordsPerSession] (null = all).
SessionPick pickSessionWords(
  WordCollection c, {
  required bool split,
  required int? wordsPerSession,
  int? lastGroup,
  int? skipGroup,
  List<String>? rowIds,
  required DateTime now,
}) {
  final learn = wordsToLearn(c);
  bool due(WordPair w) => isDue(boxOf(c.boxes, w), now);
  bool fresh(WordPair w) => boxOf(c.boxes, w) == null;

  SessionPick make(List<WordPair> words, [int? index, int count = 0]) =>
      SessionPick(
        words: words,
        groupIndex: index,
        groupCount: count,
        dueRowIds: {
          for (final w in words)
            if (due(w)) w.rowId
        },
        newRowIds: {
          for (final w in words)
            if (fresh(w)) w.rowId
        },
      );

  if (rowIds != null) {
    final wanted = rowIds.toSet();
    return make([
      for (final w in learn)
        if (wanted.contains(w.rowId)) w
    ]);
  }
  if (learn.length < splitShowsAt) return make(learn);

  if (split) {
    final groups = sessionGroups(c);
    final count = groups.length;
    int? firstWith(bool Function(WordPair) test) {
      for (var i = 0; i < count; i++) {
        if (i != skipGroup && groups[i].any(test)) return i;
      }
      return null;
    }

    final after = skipGroup ?? lastGroup;
    final index = firstWith(due) ??
        firstWith(fresh) ??
        (after == null ? 0 : (after + 1) % count);
    return make(groups[index], index, count);
  }

  final dueWords = [
    for (final w in learn)
      if (due(w)) w
  ];
  final newWords = [
    for (final w in learn)
      if (fresh(w)) w
  ];
  final others = [
    for (final w in learn)
      if (!due(w) && !fresh(w)) w
  ];
  final ordered = [...dueWords, ...newWords, ...others];
  final cap = wordsPerSession;
  return make(
      cap == null || cap >= ordered.length ? ordered : ordered.sublist(0, cap));
}

/// The Learn sheet's and the results screen's group line (AC-05):
/// "Group 2 of 4 · 9 words", or "" when the session is not split.
String sessionGroupLabel(SessionPick p) {
  final index = p.groupIndex;
  if (index == null) return '';
  return 'Group ${index + 1} of ${p.groupCount} · ${p.words.length} words';
}

/// How many words to learn are due at [now] (AC-14).
int dueCount(WordCollection c, DateTime now) =>
    wordsToLearn(c).where((w) => isDue(boxOf(c.boxes, w), now)).length;
