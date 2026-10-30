import '../../../core/models/word_box.dart';
import '../../../core/models/word_pair.dart';
import 'leitner.dart';

/// The pure rating rules of the self-check card (learn-welcome AC-07, AC-08;
/// ADR-0006; self-check-cards AC-05 – AC-07). Nothing here touches the store:
/// the notifier hands the result of [rateBox] to one `CollectionStore.update`.

/// How the learner rated a word after flipping its card.
enum SelfRating { dontRemember, hard, medium, easy }

/// The Leitner box [rating] leads to from [box] (a new word is box 0) on the
/// day [now] (AC-08): I don't remember -> 1; Hard -> max(1, box - 1); Medium
/// stays (new -> 1); Easy -> min(5, box + 1). Easy right after a mistake
/// ([afterMistake]) counts as Medium. A move up (to a higher box than before)
/// happens at most once a calendar day: if the word already moved up today it
/// keeps its box instead. Down moves always apply.
int targetBox(
  WordBox? box,
  SelfRating rating,
  DateTime now, {
  bool afterMistake = false,
}) {
  final before = box?.box ?? 0;
  final effective =
      rating == SelfRating.easy && afterMistake ? SelfRating.medium : rating;
  final target = switch (effective) {
    SelfRating.dontRemember => 1,
    SelfRating.hard => before - 1 < 1 ? 1 : before - 1,
    SelfRating.medium => before < 1 ? 1 : before,
    SelfRating.easy => before + 1 > 5 ? 5 : before + 1,
  };
  if (target > before && box != null && box.lastUpDay == _todayKey(now)) {
    return before < 1 ? 1 : before;
  }
  return target;
}

/// The new box of [row] after [rating] (AC-08): a copy of [box] (null for a
/// new word) with `box`, `dueAt` (start of today plus [intervalDays]) and
/// `lastUpDay` (set when the word moved up) updated, and `lastCheckSide` set to
/// [side], the side the card showed first (`'uk'` or `'en'`). Never changes
/// [box].
WordBox rateBox(
  WordPair row,
  WordBox? box,
  SelfRating rating,
  DateTime now, {
  required String side,
  bool afterMistake = false,
}) {
  final target = targetBox(box, rating, now, afterMistake: afterMistake);
  final local = now.toLocal();
  return WordBox()
    ..rowId = row.rowId
    ..word = boxKey(row.word)
    ..box = target
    ..dueAt =
        DateTime(local.year, local.month, local.day + intervalDays(target))
    ..lastUpDay =
        target > (box?.box ?? 0) ? _todayKey(now) : box?.lastUpDay ?? ''
    ..lastCheckSide = side;
}

/// The side the card shows first for [box] (AC-07): Ukrainian for a word never
/// checked or last checked on the English side; English if last Ukrainian.
String nextSide(WordBox? box) => box?.lastCheckSide == 'uk' ? 'en' : 'uk';

/// The caption under a rating button (AC-07): the box it leads to, "Box N".
String boxLabel(
  WordBox? box,
  SelfRating rating,
  DateTime now, {
  bool afterMistake = false,
}) =>
    'Box ${targetBox(box, rating, now, afterMistake: afterMistake)}';

String _todayKey(DateTime now) {
  final t = now.toLocal();
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
