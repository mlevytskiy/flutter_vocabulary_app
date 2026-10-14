import 'package:isar_community/isar.dart';

part 'word_result.g.dart';

/// A Step 3 exam's verdict on one word (learn-kit, H-05, S-22; D-31, D-32).
/// Stored as the ordinal: new labels only at the end, never in between.
enum WordResultLabel { known, repeat }

/// One word result, written by an exam as soon as that word's result is final
/// (S-23). Embedded inside `Session.results`, append-only, newest last; the
/// latest per [rowId] wins across exams. Never part of a word row, a publish,
/// an export or the lightning rules (AC-37).
@embedded
class WordResult {
  /// The `WordPair.rowId` of the word; a result whose row is gone is ignored.
  String rowId = '';

  /// The exam that gave it, an `Exercise.id` (e.g. `quiz`).
  String exerciseId = '';

  @Enumerated(EnumType.ordinal)
  WordResultLabel label = WordResultLabel.known;

  DateTime at = DateTime.fromMillisecondsSinceEpoch(0);

  WordResult();

  WordResult copy() => WordResult()
    ..rowId = rowId
    ..exerciseId = exerciseId
    ..label = label
    ..at = at;

  factory WordResult.fromJson(Map<String, dynamic> json) => WordResult()
    ..rowId = json['rowId'] as String? ?? ''
    ..exerciseId = json['exerciseId'] as String? ?? ''
    ..label = WordResultLabel.values.asNameMap()[json['label']] ??
        WordResultLabel.known
    ..at = DateTime.parse(json['at'] as String? ?? '1970-01-01');

  Map<String, dynamic> toJson() => {
        'rowId': rowId,
        'exerciseId': exerciseId,
        'label': label.name,
        'at': at.toIso8601String(),
      };
}
