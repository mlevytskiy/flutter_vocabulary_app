import 'package:isar_community/isar.dart';

part 'word_box.g.dart';

/// One word's Leitner box (learn-redesign, ADR-0001). Embedded inside
/// `WordCollection.boxes`, one per word row of one collection, written only
/// through `CollectionStore.update` — `put` keeps the stored ones (ADR-0002).
/// A box belongs to a row only while both [rowId] and [word] still match it;
/// otherwise the row counts as new and the box is ignored (AC-15).
@embedded
class WordBox {
  /// The `WordPair.rowId` of the word; a box whose row is gone is ignored.
  String rowId = '';

  /// The row's English word, trimmed and lower-case, when the box was written:
  /// a changed English word starts the row again as new (AC-15).
  String word = '';

  /// The Leitner box, 1–5.
  int box = 1;

  /// When the word is due again.
  DateTime dueAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The local day (`yyyy-mm-dd`) the word last moved up a box; '' if never.
  String lastUpDay = '';

  /// The side the self-check card showed first the last time it checked this
  /// word: '' (never checked), 'uk' or 'en' (learn-welcome AC-07, ADR-0006).
  String lastCheckSide = '';

  WordBox();

  WordBox copy() => WordBox()
    ..rowId = rowId
    ..word = word
    ..box = box
    ..dueAt = dueAt
    ..lastUpDay = lastUpDay
    ..lastCheckSide = lastCheckSide;

  factory WordBox.fromJson(Map<String, dynamic> json) => WordBox()
    ..rowId = json['rowId'] as String? ?? ''
    ..word = json['word'] as String? ?? ''
    ..box = json['box'] as int? ?? 1
    ..dueAt = DateTime.parse(json['dueAt'] as String? ?? '1970-01-01')
    ..lastUpDay = json['lastUpDay'] as String? ?? ''
    ..lastCheckSide = json['lastCheckSide'] as String? ?? '';

  Map<String, dynamic> toJson() => {
        'rowId': rowId,
        'word': word,
        'box': box,
        'dueAt': dueAt.toIso8601String(),
        'lastUpDay': lastUpDay,
        'lastCheckSide': lastCheckSide,
      };
}
