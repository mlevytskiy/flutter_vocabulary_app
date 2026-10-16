/// Which rows a film dialogue holds, at Done and after edits, and the name of
/// its group card (get-words-from-subtitles-improvment, sad §4). Pure: the
/// notifier applies the results (T17, T18).
library;

import '../models/film_dialogue.dart';
import '../models/word_collection.dart';
import '../models/word_pair.dart';
import '../services/source_photo_store.dart' show uuidV4;
import 'dialogue_match.dart';

/// A dialogue as the import returned it: its lines and the proposed words it
/// holds, in the words' own spelling.
typedef ImportedDialogue = ({List<String> lines, List<String> words});

String _key(String word) => word.trim().toLowerCase();

/// A word counts for a dialogue when it appears in one of its lines; a phrase
/// never spans two lines (as the Worker checks).
bool _inLines(List<String> lines, String word) =>
    lines.any((line) => appears(line, word));

/// The import's dialogues as they are kept at Done (AC-03): each linked to the
/// `rowId`s of the [kept] rows its words are, the learner's removed words
/// left out, and a dialogue left with none dropped. [kept] rows must already
/// have their row ids.
List<FilmDialogue> atDone(List<ImportedDialogue> dialogues, List<WordPair> kept,
    {String Function() newId = uuidV4}) {
  final out = <FilmDialogue>[];
  for (final imported in dialogues) {
    final words = {for (final w in imported.words) _key(w)};
    final rowIds = <String>[
      for (final row in kept)
        if (words.contains(_key(row.word)) &&
            _inLines(imported.lines, row.word))
          row.rowId,
    ];
    if (rowIds.isEmpty) continue;
    out.add(FilmDialogue()
      ..id = newId()
      ..lines = [...imported.lines]
      ..wordRowIds = rowIds);
  }
  return out;
}

/// The session's dialogues after a word changed or was deleted (AC-11, AC-26):
/// a deleted row leaves; an edited word stays only where it still appears; a
/// dialogue with no words left disappears, or is hidden while its delivery is
/// pending (ADR-0005). Links only shrink: no row ever joins here. Returns
/// copies; [collection] is not changed.
List<FilmDialogue> afterEdit(WordCollection collection) {
  final rows = {
    for (final w in collection.words)
      if (!w.isEmpty) w.rowId: w,
  };
  final out = <FilmDialogue>[];
  for (final dialogue in collection.dialogues) {
    final d = dialogue.copy()
      ..wordRowIds = [
        for (final id in dialogue.wordRowIds)
          if (rows[id] case final row? when _inLines(dialogue.lines, row.word))
            id,
      ];
    if (d.wordRowIds.isEmpty) {
      if (d.pushState != PushState.pending) continue;
      d.hidden = true;
    }
    out.add(d);
  }
  return out;
}

/// The session's dialogues once a publish carried those in [sent]
/// (ADR-0005): the page has them, so they are delivered; a hidden one is
/// gone, its import's rows having gone with the publish; a sent dialogue's
/// scene picture was declared and waits for its upload. Returns copies.
List<FilmDialogue> afterPublish(List<FilmDialogue> dialogues,
        {required Set<String> sent}) =>
    [
      for (final d in dialogues)
        if (!d.hidden)
          d.copy()
            ..pushState = PushState.delivered
            ..picturePushState =
                sent.contains(d.id) && d.scenePictureRunId != null
                    ? PushState.pending
                    : d.picturePushState,
    ];

/// Leading dashes, then a speaker label such as "A:" or "JOHN:", then dashes
/// again.
final _speakerMarks = RegExp(
    r"^\s*(?:[-–—]+\s*)?(?:[\p{L}][\p{L}\p{N} .'’]{0,23}:\s+)?(?:[-–—]+\s*)?",
    unicode: true);

const _maxCardName = 40;

String _baseName(FilmDialogue dialogue) {
  final first = dialogue.lines.isEmpty ? '' : dialogue.lines.first;
  final name = first.replaceFirst(_speakerMarks, '').trim();
  return name.length > _maxCardName
      ? '${name.substring(0, _maxCardName)}…'
      : name;
}

/// A dialogue group card's name (AC-13): the first line without speaker
/// marks, cut to 40 characters with "…", and "(2)", "(3)" when an earlier
/// dialogue in [all] (the carded dialogues, in pager order) has the same name.
String cardName(FilmDialogue dialogue, List<FilmDialogue> all) {
  final name = _baseName(dialogue);
  var seen = 0;
  for (final other in all) {
    if (identical(other, dialogue) || other.id == dialogue.id) break;
    if (_baseName(other) == name) seen++;
  }
  return seen == 0 ? name : '$name (${seen + 1})';
}
