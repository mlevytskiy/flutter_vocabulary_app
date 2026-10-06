import '../models/vocab_word.dart';
import 'quizlet_set_parser.dart';

/// Longest text a shared page accepts in one field, the "…" included.
const int quizletFieldLimit = 500;

/// What the cards of a set give: the words to propose and the numbers the
/// results dialog names.
class QuizletProposal {
  const QuizletProposal({
    required this.words,
    required this.skipped,
    required this.found,
    required this.stated,
  });

  /// Proposed words in set order: the back side in the field it fits (see
  /// [backIsTranslation]), every other field null; description = definition.
  final List<VocabWord> words;

  /// Cards skipped on purpose: no text term, already in the session, repeated.
  final int skipped;

  /// Cards found on the page, counted before any skipping.
  final int found;

  /// The count the page states, or null when it states none.
  final int? stated;

  /// "Read X of Y cards" when fewer cards were found than the page states.
  String? get readLine {
    final s = stated;
    if (s == null || found >= s) return null;
    return 'Read $found of $s cards';
  }
}

/// Turns [cards] into proposed words (AC-04b, AC-08, AC-09, AC-10).
QuizletProposal proposeWords(
  List<QuizletCard> cards,
  Iterable<String> sessionWords,
  int? statedCount,
) {
  final seen = <String>{for (final w in sessionWords) _sameKey(w)};
  final words = <VocabWord>[];
  var skipped = 0;
  for (final card in cards) {
    final term = _cut(_oneLine(card.term));
    if (term.isEmpty) {
      skipped++;
      continue;
    }
    if (!seen.add(_sameKey(term))) {
      skipped++;
      continue;
    }
    final back = _oneLine(card.back);
    final example = _oneLine(card.example);
    // No machine translation: a Ukrainian back is the translation, any other
    // back is the definition; the example always belongs to the definition.
    final translation = backIsTranslation(back) ? back : '';
    final definition = [if (translation.isEmpty) back, example]
        .where((s) => s.isNotEmpty)
        .join('\n');
    // An empty field is null, so the results dialog shows no line for it.
    words.add(VocabWord(
      word: term,
      translation: translation.isEmpty ? null : _cut(translation),
      description: definition.isEmpty ? null : _cut(definition),
    ));
  }
  return QuizletProposal(
    words: words,
    skipped: skipped,
    found: cards.length,
    stated: statedCount,
  );
}

/// Whether a card's back side is a translation rather than a definition: at
/// least half of its letters are Cyrillic, as in a Ukrainian translation. An
/// English explanation (the owner's example set) is a definition.
bool backIsTranslation(String back) {
  var letters = 0;
  var cyrillic = 0;
  for (final r in back.runes) {
    final c = String.fromCharCode(r);
    if (c.toLowerCase() == c.toUpperCase()) continue; // not a letter
    letters++;
    if (r >= 0x0400 && r <= 0x052F) cyrillic++;
  }
  return letters > 0 && cyrillic * 2 >= letters;
}

/// Line breaks become "; "; blank lines and outer spaces are dropped.
String _oneLine(String text) => text
    .split(RegExp(r'\r\n|\r|\n'))
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .join('; ');

/// Cuts to [quizletFieldLimit] characters, the last one being "…".
String _cut(String text) {
  final runes = text.runes.toList();
  if (runes.length <= quizletFieldLimit) return text;
  return '${String.fromCharCodes(runes.take(quizletFieldLimit - 1))}…';
}

/// Two words are the same when equal ignoring capitals, outer spaces and
/// one closing ".", "!" or "?" (AC-10).
String _sameKey(String text) {
  var t = text.trim().toLowerCase();
  if (t.endsWith('.') || t.endsWith('!') || t.endsWith('?')) {
    t = t.substring(0, t.length - 1);
  }
  return t.trim();
}
