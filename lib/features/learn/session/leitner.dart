import '../../../core/models/word_box.dart';
import '../../../core/models/word_pair.dart';
import 'self_check.dart';

/// The pure Leitner rules of a learning session or a talk (learn-redesign
/// ADR-0001, ADR-0002; AC-12, AC-13, AC-15, AC-22). Nothing here touches the
/// store: the session notifier hands the result of [applySession] to one
/// `CollectionStore.update` at the end.

/// The key a box keeps of its row's English word: trimmed and lower-case, so
/// a changed English word starts the row again as new (AC-15).
String boxKey(String word) => word.trim().toLowerCase();

/// The box of [row] in [boxes]: the one with the row's `rowId` whose word is
/// still the row's English word; null when the row is new (AC-15).
WordBox? boxOf(List<WordBox> boxes, WordPair row) {
  final key = boxKey(row.word);
  for (final box in boxes) {
    if (box.rowId == row.rowId && box.word == key) return box;
  }
  return null;
}

/// Whether [box] is due at [now], by local calendar day: due when its
/// `dueAt` falls on today or earlier. A new word (no box) is never due.
bool isDue(WordBox? box, DateTime now) =>
    box != null && !_day(box.dueAt).isAfter(_day(now));

/// Days until the next review for Leitner box 1–5: 1, 2, 4, 8, 16 (AC-13).
int intervalDays(int box) => 1 << (box.clamp(1, 5) - 1);

/// How a word ended a session: no flag, flagged by a mistake ([missed]),
/// flagged by a hint ([hinted]; right only after a hint), or (in a talk) never
/// used (AC-13, AC-22; self-check-cards AC-01, Q-3).
enum WordOutcome { clean, missed, hinted, unused }

/// Whether [outcome] marks its word *to check* (self-check-cards AC-01).
bool isFlagged(WordOutcome outcome) =>
    outcome == WordOutcome.missed || outcome == WordOutcome.hinted;

/// A flagged word's self-check rating (self-check-cards AC-05): the [rating]
/// and the card [side] it showed first (`'uk'` or `'en'`).
typedef WordRating = ({SelfRating rating, String side});

/// A word's line on the results screen (AC-12, AC-22): known well (no flag),
/// shaky (flagged, not new before), new (flagged, new before), unused (a talk's
/// word never used — box unchanged).
enum WordState { knownWell, shaky, isNew, unused }

/// One word's box move in a finished session, for the results screen.
class SessionMove {
  final String rowId;

  /// The row's English word as the learner wrote it.
  final String word;
  final WordState state;

  /// A copy of the box before the session; null when the word was new.
  final WordBox? before;

  /// The box after the session; null for a new word that kept no box (unused,
  /// or flagged and never rated).
  final WordBox? after;

  /// The self-check rating that moved a flagged word (self-check-cards
  /// AC-10); null for a clean or unused word and for a flagged word never
  /// rated, which kept its box (AC-09).
  final SelfRating? rating;

  const SessionMove({
    required this.rowId,
    required this.word,
    required this.state,
    this.before,
    this.after,
    this.rating,
  });
}

/// Moves the boxes of a finished session (AC-13; self-check-cards AC-01,
/// AC-05 – AC-10) and returns the new box list with one [SessionMove] per word
/// in [outcomes]. Never changes its inputs.
///
/// A clean word moves up one box (a new word to box 1, box 5 stays 5) unless
/// it already moved up today, then it keeps its box; the next review is the
/// start of today plus [intervalDays] (AC-08). A flagged word (missed or
/// hinted) does not move by its flag: with a rating in [ratings] it moves by
/// [rateBox] from its box before the session, Easy counting as Medium when the
/// flag came from a mistake (AC-05 – AC-07), and stores the card's side;
/// without a rating it keeps its box and next review (AC-09). An unused word
/// keeps its box and next review. Ratings of unflagged words are ignored. A
/// row whose English word changed loses its old box and counts as new (AC-15).
/// Boxes of words not in [outcomes] stay as they are, except that, when
/// [liveRowIds] is given, boxes of rows no longer in it are dropped.
({List<WordBox> boxes, List<SessionMove> moves}) applySession(
  List<WordBox> boxes,
  Map<WordPair, WordOutcome> outcomes,
  DateTime now, {
  Map<WordPair, WordRating> ratings = const {},
  Set<String>? liveRowIds,
}) {
  final today = _day(now);
  final todayKey = _dayKey(today);
  final result = [
    for (final box in boxes)
      if (liveRowIds == null || liveRowIds.contains(box.rowId)) box.copy(),
  ];
  final moves = <SessionMove>[];

  outcomes.forEach((row, outcome) {
    final before = boxOf(result, row)?.copy();
    if (outcome == WordOutcome.unused) {
      moves.add(SessionMove(
        rowId: row.rowId,
        word: row.word,
        state: WordState.unused,
        before: before,
        after: before?.copy(),
      ));
      return;
    }

    final flagged = isFlagged(outcome);
    final flagState = before == null ? WordState.isNew : WordState.shaky;
    final rated = flagged ? ratings[row] : null;
    if (flagged && rated == null) {
      // Flagged, never rated: box and next review kept (AC-09).
      moves.add(SessionMove(
        rowId: row.rowId,
        word: row.word,
        state: flagState,
        before: before,
        after: before?.copy(),
      ));
      return;
    }

    final WordBox after;
    if (rated != null) {
      after = rateBox(row, before, rated.rating, now,
          side: rated.side, afterMistake: outcome == WordOutcome.missed);
    } else {
      final int box;
      var lastUpDay = before?.lastUpDay ?? '';
      if (before != null && before.lastUpDay == todayKey) {
        box = before.box;
      } else {
        box = before == null ? 1 : (before.box + 1).clamp(1, 5);
        lastUpDay = todayKey;
      }
      after = WordBox()
        ..rowId = row.rowId
        ..word = boxKey(row.word)
        ..box = box
        ..dueAt =
            DateTime(today.year, today.month, today.day + intervalDays(box))
        ..lastUpDay = lastUpDay
        ..lastCheckSide = before?.lastCheckSide ?? '';
    }

    // One box per row: a box left by an edited English word is replaced.
    result
      ..removeWhere((b) => b.rowId == row.rowId)
      ..add(after);
    moves.add(SessionMove(
      rowId: row.rowId,
      word: row.word,
      state: flagged ? flagState : WordState.knownWell,
      before: before,
      after: after.copy(),
      rating: rated?.rating,
    ));
  });

  return (boxes: result, moves: moves);
}

/// The results screen's next review (AC-12): "today", "tomorrow" or
/// "in N days", counted in local calendar days.
String nextReviewText(DateTime dueAt, DateTime now) {
  final a = _day(now), b = _day(dueAt);
  final days = DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

DateTime _day(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _dayKey(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
