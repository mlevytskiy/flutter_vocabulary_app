import 'match_board.dart';
import 'word_marks.dart';

/// The definition line of a stored definition (S-40): the rest of the first
/// line that starts with "definition:" (any case), else the first non-empty
/// line that does not start with "example:", else "". Covers a picked
/// dictionary sense, a Quizlet back plus example, and typed text.
String definitionText(String stored) {
  final lines = [for (final l in stored.split('\n')) l.trim()];
  for (final l in lines) {
    if (l.toLowerCase().startsWith('definition:')) return l.substring('definition:'.length).trim();
  }
  for (final l in lines) {
    if (l.isNotEmpty && !l.toLowerCase().startsWith('example:')) return l;
  }
  return '';
}

/// The text a match card shows for a definition of [word] (S-40):
/// `cardText(maskWord(definitionText(text), word))`. Null when it says nothing
/// (no letter or digit besides "___"), which counts as no definition.
String? definitionCard(String text, String word) {
  final line = definitionText(text);
  if (line.isEmpty) return null;
  final card = cardText(maskWord(line, word.trim()));
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(card.replaceAll('___', ''))) return null;
  return card;
}
