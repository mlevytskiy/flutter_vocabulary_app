import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_pair.dart';
import 'word_marks.dart';

/// S-31 (D-20 source 1): the first line, in dialogue order then line order, of a
/// visible dialogue linked to [word] that holds the word exactly once; else null.
String? exampleLineFor(WordPair word, List<FilmDialogue> dialogues) {
  if (word.rowId.isEmpty) return null;
  for (final d in dialogues) {
    if (d.hidden || !d.wordRowIds.contains(word.rowId)) continue;
    for (final line in d.lines) {
      if (holdsWordOnce(line, word.word)) return line;
    }
  }
  return null;
}
