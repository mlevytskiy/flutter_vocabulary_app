/// Part-of-speech priority used to pick the default translation and to order
/// groups in the "more options" popup: noun first, then verb, adjective,
/// adverb, and whatever else Google returns after that (in its own order).
const List<String> kPosPriority = ['noun', 'verb', 'adjective', 'adverb'];

/// One translation candidate from Google's dictionary block, e.g.
/// word = "дім", backTranslations = ["house", "home", "family", ...].
class DictionaryWord {
  final String word;

  /// English meanings this candidate covers -- useful to explain the sense.
  final List<String> backTranslations;

  const DictionaryWord({
    required this.word,
    this.backTranslations = const [],
  });
}

/// One part-of-speech group from the dictionary block, e.g. pos = "noun".
class DictionaryEntry {
  /// "noun", "verb", "adjective", "adverb", ... (English labels).
  final String pos;
  final List<DictionaryWord> words;

  const DictionaryEntry({required this.pos, required this.words});

  List<String> get wordList => words.map((w) => w.word).toList();

  bool contains(String candidate) {
    final c = candidate.trim().toLowerCase();
    return words.any((w) => w.word.toLowerCase() == c);
  }
}

/// A raw translation: the primary text plus everything Google knows about
/// alternative renderings of the same input.
class TranslationResult {
  /// Primary machine translation (what translate.google.com shows on top).
  /// For an ambiguous bare word Google picks one sense -- e.g.
  /// "home" -> "додому" (an adverb).
  final String text;

  /// Ranked alternative translations for the whole input, best first.
  /// Usually 1-3 items; may repeat [text].
  final List<String> alternatives;

  /// ISO code Google detected for the input (meaningful when `from` was
  /// 'auto').
  final String detectedSourceLanguage;

  /// Alternatives grouped by part of speech. Empty for phrases/sentences and
  /// for words Google has no dictionary data for.
  final List<DictionaryEntry> dictionary;

  const TranslationResult({
    required this.text,
    this.alternatives = const [],
    this.detectedSourceLanguage = '',
    this.dictionary = const [],
  });

  bool get hasDictionary => dictionary.isNotEmpty;

  DictionaryEntry? byPos(String pos) {
    for (final e in dictionary) {
      if (e.pos == pos) return e;
    }
    return null;
  }

  /// [dictionary] reordered by [kPosPriority]; groups not in the priority
  /// list keep their relative order after it.
  List<DictionaryEntry> get dictionaryByPriority {
    final ordered = <DictionaryEntry>[];
    for (final pos in kPosPriority) {
      final e = byPos(pos);
      if (e != null) ordered.add(e);
    }
    for (final e in dictionary) {
      if (!kPosPriority.contains(e.pos)) ordered.add(e);
    }
    return ordered;
  }

  /// Ranked candidates for the input: primary first, then alternatives,
  /// de-duplicated.
  List<String> get rankedCandidates {
    final seen = <String>{};
    final out = <String>[];
    for (final c in [text, ...alternatives]) {
      final k = c.trim().toLowerCase();
      if (k.isEmpty || !seen.add(k)) continue;
      out.add(c.trim());
    }
    return out;
  }
}

/// A [TranslationResult] plus the single translation chosen by the
/// part-of-speech rule -- what the Translation field is filled with.
class WordTranslation {
  final TranslationResult result;

  /// The translation to put in the Translation field.
  final String best;

  /// Part of speech [best] was taken from, or null when it is just the plain
  /// machine translation (no dictionary data).
  final String? bestPos;

  const WordTranslation({
    required this.result,
    required this.best,
    this.bestPos,
  });
}
