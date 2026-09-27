/// Heuristic for "did we get an actual translation, or just an echo of
/// the input back?" Google Translate (via the `translator` package)
/// doesn't signal failure when it has no translation for the input --
/// it silently returns the input text unchanged (seen for short or
/// ambiguous words, proper nouns, or when there's simply no distinct
/// translation available). Comparing the (trimmed) input and output
/// catches that case. See docs/lightning_icon_rules.md.
bool isRealTranslation(String input, String output) {
  return output.trim() != input.trim();
}

/// Whether [char] (expected to be a single character) is an ASCII
/// English letter. Used to guess whether the Word field's content is
/// English by looking at just its first letter -- see
/// docs/lightning_icon_rules.md.
bool isEnglishLetter(String char) {
  return RegExp(r'^[A-Za-z]$').hasMatch(char);
}

/// Definition icon (definition-mode, docs/lightning_icon_rules.md): shown
/// only while the row has focus (Rule 0), the Word has 2+ letters, and the
/// Definition is not yet "filled" -- more than 5 characters, or
/// auto-populated. Mirrors the Translation icon rule.
bool shouldShowDefinitionIcon({
  required bool rowFocused,
  required String word,
  required String definition,
  required bool marked,
}) {
  if (!rowFocused) return false;
  if (word.trim().length < 2) return false;
  final filled = definition.trim().length > 5 || marked;
  return !filled;
}
