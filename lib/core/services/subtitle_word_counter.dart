import '../models/subtitle_import_options.dart';
import 'subtitle_ignored_words.dart';

/// What the phone sends the Worker for one subtitle import: the most frequent
/// words, most frequent first, and only the subtitle lines around the places
/// they are used — never the whole file.
class SubtitlePick {
  const SubtitlePick({required this.words, required this.lines, this.contexts = const {}});

  final List<String> words;

  /// Each word's context: the line it is used in with one line on each side.
  final Map<String, String> contexts;

  /// Excerpts in file order; [SubtitleWordCounter.gap] stands between two
  /// excerpts that are not next to each other in the film.
  final List<String> lines;

  bool get isEmpty => words.isEmpty;
}

/// Picks the most frequent words of a subtitle file on the phone. Pure Dart,
/// no I/O. A word's score is how often it is used plus [closeRepeatWeight]
/// for each close repeat — a use within [closeRepeatLines] lines of the one
/// before, so a word the film keeps returning to in one scene ranks above one
/// scattered over the film. Counting is by lower-case word: contractions lose their ending
/// ("don't" → "do"), a plural joins its singular when both are used
/// ("doors" → "door"), and a word is skipped when the learner's level already
/// knows it ([subtitleIgnoredWordsFor]), it is already in the session, a single letter, a number
/// ([numberWords]; digits are never read as words), or —
/// with removeNames on — looks like a name ([looksLikeName]).
abstract final class SubtitleWordCounter {
  /// More candidates than the maximum, so the Worker can still fill it after
  /// turning words into their base forms and dropping repeats.
  static const extraCandidates = 10;

  /// Places per word sent as context, and lines kept on each side of a place.
  static const placesPerWord = 2;
  static const neighbourLines = 1;

  /// A use of a word this many lines or fewer after the one before (0: the
  /// same line) is a close repeat, and each close repeat adds this much.
  static const closeRepeatLines = 2;
  static const closeRepeatWeight = 3;

  /// A context line this long or longer is taken at the word's first place.
  static const contextMinWords = 4;

  /// Lines taken on each side of that line for the context.
  static const contextNeighbourLines = 1;

  /// The line standing between two excerpts that are not next to each other.
  static const gap = '...';

  static final _token = RegExp(r"[a-zA-Z]+(?:['’][a-zA-Z]+)*");
  static final _sentenceEnd = RegExp(r'[.!?…]["”’)]*\s*$');

  /// Numbers written as words, cardinal and ordinal, never proposed:
  /// "eleven", "ninety", "fourth", "hundredth". "twenty-one" is read as
  /// "twenty" and "one", both here.
  static const numberWords = {
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
    'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
    'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
    'hundred', 'thousand', 'million', 'billion', 'trillion',
    'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth',
    'eleventh', 'twelfth', 'thirteenth', 'fourteenth', 'fifteenth', 'sixteenth', 'seventeenth', 'eighteenth',
    'nineteenth', 'twentieth', 'thirtieth', 'fortieth', 'fiftieth', 'sixtieth', 'seventieth', 'eightieth',
    'ninetieth', 'hundredth', 'thousandth', 'millionth', 'billionth',
    'hundreds', 'thousands', 'millions', 'billions',
  };

  static const _irregularNegatives = {'ca': 'can', 'wo': 'will', 'sha': 'shall', 'ai': ''};
  static const _endings = ['s', 're', 'll', 've', 'd', 'm'];

  static SubtitlePick pick(
    List<String> lines, {
    required int maximum,
    required EnglishLevel level,
    List<String> collectionWords = const [],
    bool boostCloseRepeats = true,
    bool removeNames = true,
  }) {
    final uses = <String, List<int>>{}; // the line of every use, in order
    final firstSeen = <String, int>{};
    final places = <String, List<int>>{};
    final lowerSeen = <String>{};
    final capitalInside = <String>{};

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      var sentenceStart = true;
      var previousEnd = 0;
      for (final match in _token.allMatches(line)) {
        if (_sentenceEnd.hasMatch(line.substring(previousEnd, match.start))) sentenceStart = true;
        previousEnd = match.end;
        final raw = match.group(0)!;
        final word = _withoutEnding(raw.toLowerCase().replaceAll('’', "'"));
        final atStart = sentenceStart;
        sentenceStart = false;
        if (word.length < 2) continue;
        if (raw[0] == raw[0].toLowerCase()) {
          lowerSeen.add(word);
        } else if (!atStart && raw.toLowerCase() != 'i') {
          capitalInside.add(word);
        }
        (uses[word] ??= []).add(lineIndex);
        firstSeen.putIfAbsent(word, () => uses.length);
        final at = places.putIfAbsent(word, () => []);
        if (at.isEmpty || at.last != lineIndex) at.add(lineIndex);
      }
    }

    _joinPlurals(uses, places, lowerSeen);

    final skip = {...subtitleIgnoredWordsFor(level), ...numberWords, for (final w in collectionWords) w.trim().toLowerCase()};
    final scores = {for (final entry in uses.entries) entry.key: score(entry.value, boostCloseRepeats: boostCloseRepeats)};
    final ranked = uses.keys
        .where((w) => !skip.contains(w))
        .where((w) => !removeNames ||
            !looksLikeName(
              capitalInside: capitalInside.contains(w),
              lowerSeen: lowerSeen.contains(w),
              uses: uses[w]!.length,
              common: subtitleCommonWordSet.contains(w),
            ))
        .toList()
      ..sort((a, b) {
        final byScore = scores[b]!.compareTo(scores[a]!);
        return byScore != 0 ? byScore : firstSeen[a]!.compareTo(firstSeen[b]!);
      });
    final words = ranked.take(maximum + extraCandidates).toList();

    final kept = <int>{};
    for (final word in words) {
      for (final place in _spread(places[word]!)) {
        for (var i = place - neighbourLines; i <= place + neighbourLines; i++) {
          if (i >= 0 && i < lines.length) kept.add(i);
        }
      }
    }
    final excerpts = <String>[];
    int? previous;
    for (final i in kept.toList()..sort()) {
      if (previous != null && i != previous + 1) excerpts.add(gap);
      excerpts.add(lines[i]);
      previous = i;
    }
    return SubtitlePick(
      words: words,
      lines: excerpts,
      contexts: {for (final word in words) word: _context(lines, _contextLine(lines, places[word]!))},
    );
  }

  /// A word is taken for a name when it is never written in lower case and
  /// either has a capital inside a sentence ("Call Lila now") or is used at
  /// least twice, always capitalised, and is not a common English word
  /// ("Lila!", "Elena, wait." at the start of lines). A common word used only
  /// at line starts ("Listen.", "Hush.") and a word used once at a sentence
  /// start are kept: nothing says they are names.
  static bool looksLikeName({
    required bool capitalInside,
    required bool lowerSeen,
    required int uses,
    required bool common,
  }) {
    if (lowerSeen) return false;
    return capitalInside || (uses >= 2 && !common);
  }

  /// How often a word is used plus [closeRepeatWeight] for each use within
  /// [closeRepeatLines] lines of the one before. [uses] is the line of every
  /// use, in order: [3, 4, 20] is 3 uses and 1 close repeat, so 3 + 3 = 6.
  /// With [boostCloseRepeats] off it is the number of uses alone.
  static int score(List<int> uses, {bool boostCloseRepeats = true}) {
    if (!boostCloseRepeats) return uses.length;
    var closeRepeats = 0;
    for (var i = 1; i < uses.length; i++) {
      if (uses[i] - uses[i - 1] <= closeRepeatLines) closeRepeats++;
    }
    return uses.length + closeRepeatWeight * closeRepeats;
  }

  /// The first place that reads like a sentence (at least [contextMinWords]
  /// words), else the longest line the word is used in.
  static int _contextLine(List<String> lines, List<int> at) {
    for (final i in at) {
      if (_token.allMatches(lines[i]).length >= contextMinWords) return i;
    }
    return at.reduce((a, b) => lines[b].length > lines[a].length ? b : a);
  }

  /// The line at [at] with [contextNeighbourLines] lines on each side, joined
  /// into one passage: "Where's the boat? The harbour is empty. Look!".
  static String _context(List<String> lines, int at) {
    final from = (at - contextNeighbourLines).clamp(0, lines.length - 1);
    final to = (at + contextNeighbourLines).clamp(0, lines.length - 1);
    return lines.sublist(from, to + 1).join(' ');
  }

  /// "don't" → "do", "can't" → "can", "I'm" → "i", "Tom's" → "tom".
  static String _withoutEnding(String word) {
    if (!word.contains("'")) return word;
    if (word.endsWith("n't")) {
      final stem = word.substring(0, word.length - 3);
      return _irregularNegatives[stem] ?? stem;
    }
    final cut = word.lastIndexOf("'");
    final ending = word.substring(cut + 1);
    return _endings.contains(ending) ? word.substring(0, cut) : word.replaceAll("'", '');
  }

  /// A plural used beside its singular counts as the singular: "doors" →
  /// "door", "boxes" → "box", "stories" → "story".
  static void _joinPlurals(Map<String, List<int>> uses, Map<String, List<int>> places, Set<String> lowerSeen) {
    for (final plural in uses.keys.toList()) {
      if (plural.length < 4 || !plural.endsWith('s') || plural.endsWith('ss')) continue;
      final singular = [
        if (plural.endsWith('ies')) '${plural.substring(0, plural.length - 3)}y',
        if (plural.endsWith('es')) plural.substring(0, plural.length - 2),
        plural.substring(0, plural.length - 1),
      ].where(uses.containsKey).firstOrNull;
      if (singular == null) continue;
      uses[singular] = [...uses[singular]!, ...uses.remove(plural)!]..sort();
      places[singular] = ({...places[singular]!, ...places.remove(plural)!}.toList()..sort());
      if (lowerSeen.contains(plural)) lowerSeen.add(singular);
    }
  }

  /// Up to [placesPerWord] places, spread over the film: the first and the last.
  static List<int> _spread(List<int> at) =>
      at.length <= placesPerWord ? at : [at.first, at.last];
}
