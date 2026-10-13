/// The AC-05 matching rule, ported from the Worker's `word-check.ts` so the app
/// and the shared page bold the same places. A word counts as a whole word in
/// any letter case; a phrase counts when its words appear in order, next to
/// each other; each English word may carry the ending -s, -es, -ed or -ing.
/// Anything else (a word inside another word, another form, a translation)
/// does not count. Pinned by `vocab-photo-api/src/story/match-cases.json`.
library;

const _endings = ['', 's', 'es', 'ed', 'ing'];

/// Words: runs of letters, digits and inner apostrophes. Other characters
/// separate.
final _word = RegExp(r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*", unicode: true);

class _Token {
  /// Lower-cased text, for comparing.
  final String text;

  /// Where the token sits in the original text: UTF-16 code units,
  /// [start, end).
  final int start;
  final int end;

  _Token(this.text, this.start, this.end);
}

List<_Token> _tokenize(String text) => [
      for (final m in _word.allMatches(text))
        _Token(m[0]!.toLowerCase(), m.start, m.end),
    ];

/// Does this text token equal the word, or the word plus one allowed ending?
bool _matches(String token, String word) =>
    _endings.any((ending) => token == word + ending);

bool _phraseAt(List<_Token> text, int start, List<_Token> phrase) {
  if (start + phrase.length > text.length) return false;
  for (var i = 0; i < phrase.length; i++) {
    if (!_matches(text[start + i].text, phrase[i].text)) return false;
  }
  return true;
}

/// Every place the word (or phrase) appears in the text, as [start, end) in
/// UTF-16 code units, in text order, without overlap. Empty when the word is
/// blank or absent.
List<({int start, int end})> matchPlaces(String text, String word) {
  final phrase = _tokenize(word);
  final tokens = _tokenize(text);
  final places = <({int start, int end})>[];
  if (phrase.isEmpty) return places;
  for (var start = 0; start < tokens.length;) {
    if (_phraseAt(tokens, start, phrase)) {
      places.add((
        start: tokens[start].start,
        end: tokens[start + phrase.length - 1].end
      ));
      start += phrase.length;
    } else {
      start++;
    }
  }
  return places;
}

/// Whether the word (or phrase) appears in the text at least once.
bool appears(String text, String word) => matchPlaces(text, word).isNotEmpty;
