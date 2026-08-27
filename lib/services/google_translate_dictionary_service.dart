import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of a single [fetchTranslationWithDictionary] call: the primary
/// (top-line) translation plus a flat, deduped list of dictionary
/// alternates across all parts of speech.
class TranslationWithAlternatives {
  const TranslationWithAlternatives(this.primaryTranslation, this.alternatives);

  final String primaryTranslation;

  /// All distinct words/phrases from Google's dictionary data for this
  /// word, flattened across every part-of-speech group (noun, verb,
  /// adjective, ...) and deduped case/whitespace-insensitively.
  ///
  /// Deliberately NOT filtered to exclude [primaryTranslation] even if it
  /// happens to also appear here: the dictionary data is a separate,
  /// self-contained data source in the response (Google's "did you mean
  /// one of these senses" box), and treating it as its own honest list --
  /// rather than silently hiding whichever entry happens to coincide with
  /// the NMT engine's top pick -- is simpler and less surprising.
  final List<String> alternatives;
}

/// Fetches a translation for [word] from the same unofficial Google
/// Translate endpoint the app already uses via the `translator` package
/// (translate.googleapis.com/translate_a/single), but requests Google's
/// `dt=bd` ("dictionary") data flag alongside the normal `dt=t` translation
/// flag, in one round-trip -- the same trick that powers the dictionary
/// box on translate.google.com. This gets both the primary translation and
/// a list of alternate senses/base forms in a single network call.
///
/// Returns `null` on any error, timeout, unexpected response shape, or
/// empty primary translation -- callers should fall back to the existing
/// translator-package-only flow in that case. Never throws.
///
/// ## Verified response shape (as of 2026; endpoint is undocumented/
/// unofficial, so this can change without notice -- see caveats below)
///
/// The JSON response is a top-level array. For a query like
/// `q=bank&dt=t&dt=bd`, it looks like (trimmed):
/// ```
/// [
///   [["банку","bank",null,null,3,null,null,[[]],[[...]]]],  // [0]: translation segments
///   [                                                          // [1]: dictionary groups (omitted/null if none)
///     ["adjective", ["банківський"], [[...back-translations...]], "bank", 3],
///     ["noun", ["банк","берег","дамба", ...16 words], [[...]], "bank", 1],
///     ["verb", ["класти гроші в банк", ...13 words], [[...]], "bank", 2]
///   ],
///   "en",  // [2]: detected source language
///   ...
/// ]
/// ```
/// - `data[0]` is a list of translation segments; concatenating
///   `segment[0]` for each (mirroring exactly what the `translator`
///   package itself does internally) gives the full primary translation.
/// - `data[1]`, when present, is a list of `[partOfSpeech, words, details,
///   originalWord, rank]` groups. `words` (index 1 of each group) is the
///   flat list of alternate translations for that part of speech -- that's
///   the piece flattened into [TranslationWithAlternatives.alternatives].
/// - This was verified empirically via direct HTTP calls for "bank" and
///   "demanding", and cross-checked to confirm the primary translation
///   returned here is byte-for-byte identical to what the app's existing
///   `GoogleTranslator().translate()` call (from the `translator` package)
///   returns for the same words -- adding `dt=bd` does not change the
///   primary translation.
Future<TranslationWithAlternatives?> fetchTranslationWithDictionary(
  String word, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return null;

  try {
    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': 'en',
        'tl': 'uk',
        'hl': 'uk',
        'dt': ['t', 'bd'],
        'ie': 'UTF-8',
        'oe': 'UTF-8',
        'otf': '1',
        'ssel': '0',
        'tsel': '0',
        'kc': '7',
        // Required: translate.googleapis.com rejects (429s) requests to
        // this client/host combination without a valid per-query token --
        // this isn't optional rate-limiting, it's basic request validation.
        'tk': _generateToken(trimmed),
        'q': trimmed,
      },
    );

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return null;

    return parseTranslationWithDictionaryResponse(response.body);
  } catch (_) {
    // Network error, timeout, malformed/unexpected JSON shape, etc. -- this
    // undocumented endpoint has no SLA and can change or rate-limit without
    // notice, so any failure here just means "use the fallback flow".
    return null;
  }
}

/// Parses a raw `translate_a/single` (with `dt=t&dt=bd`) response body into
/// a [TranslationWithAlternatives], per the shape documented on
/// [fetchTranslationWithDictionary]. Exposed as a top-level function
/// (rather than kept private) so it can be unit tested directly against
/// sample/captured response bodies without a live network call. Returns
/// `null` if the shape doesn't match what's expected or the primary
/// translation comes back empty.
TranslationWithAlternatives? parseTranslationWithDictionaryResponse(
  String responseBody,
) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! List || decoded.isEmpty) return null;

    final segments = decoded[0];
    if (segments is! List) return null;
    final primaryTranslation = segments
        .map((segment) =>
            segment is List && segment.isNotEmpty ? segment[0]?.toString() ?? '' : '')
        .join()
        .trim();
    if (primaryTranslation.isEmpty) return null;

    final dictionaryGroups = decoded.length > 1 ? decoded[1] : null;
    final seenLowercase = <String>{};
    final alternatives = <String>[];
    if (dictionaryGroups is List) {
      for (final group in dictionaryGroups) {
        if (group is! List || group.length < 2) continue;
        final wordsForPos = group[1];
        if (wordsForPos is! List) continue;
        for (final candidate in wordsForPos) {
          final candidateWord = candidate?.toString().trim();
          if (candidateWord == null || candidateWord.isEmpty) continue;
          if (seenLowercase.add(candidateWord.toLowerCase())) {
            alternatives.add(candidateWord);
          }
        }
      }
    }

    return TranslationWithAlternatives(primaryTranslation, alternatives);
  } catch (_) {
    return null;
  }
}

/// Generates the `tk` query parameter translate.googleapis.com requires
/// for the `client=gtx`/`client=t` request shape. This is a long-public,
/// widely reverse-engineered algorithm (used by many open-source Google
/// Translate clients, including the `translator` pub package this app
/// already depends on) based on a fixed "TKK" seed pair; it is not a
/// secret, just an undocumented request-shaping quirk of this endpoint.
/// Reimplemented directly here (rather than reaching into the `translator`
/// package's private `src/` implementation) so this service doesn't depend
/// on another package's internal, non-API-contract file layout.
String _generateToken(String text) {
  const seedA = 406398;
  const seedB = 561666268 + 1526272306;

  final bytes = <int>[];
  for (var i = 0; i < text.length; i++) {
    final codeUnit = text.codeUnitAt(i);
    if (codeUnit < 128) {
      bytes.add(codeUnit);
    } else if (codeUnit < 2048) {
      bytes.add(codeUnit >> 6 | 192);
      bytes.add(codeUnit & 63 | 128);
    } else if (codeUnit & 64512 == 55296 &&
        i + 1 < text.length &&
        text.codeUnitAt(i + 1) & 64512 == 56320) {
      final surrogatePair =
          65536 + ((codeUnit & 1023) << 10) + (text.codeUnitAt(++i) & 1023);
      bytes.add(surrogatePair >> 18 | 240);
      bytes.add(surrogatePair >> 12 & 63 | 128);
      bytes.add(surrogatePair >> 6 & 63 | 128);
      bytes.add(surrogatePair & 63 | 128);
    } else {
      bytes.add(codeUnit >> 12 | 224);
      bytes.add(codeUnit >> 6 & 63 | 128);
      bytes.add(codeUnit & 63 | 128);
    }
  }

  var acc = seedA;
  for (final byte in bytes) {
    acc += byte;
    acc = _scramble(acc, '+-a^+6');
  }
  acc = _scramble(acc, '+-3^+b+-f');
  acc ^= seedB;
  if (acc < 0) {
    acc = (acc & 2147483647) + 2147483648;
  }
  acc %= 1000000;
  return '$acc.${acc ^ seedA}';
}

int _scramble(int value, String op) {
  for (var i = 0; i < op.length - 2; i += 3) {
    final rawShift = op[i + 2];
    final shift = rawShift.codeUnitAt(0) >= 'a'.codeUnitAt(0)
        ? rawShift.codeUnitAt(0) - 87
        : int.parse(rawShift);
    final shifted =
        op[i + 1] == '+' ? _unsignedRightShift(value, shift) : value << shift;
    value = op[i] == '+' ? (value + shifted) & 4294967295 : value ^ shifted;
  }
  return value;
}

int _unsignedRightShift(int value, int shift) {
  if (shift >= 32 || shift < -32) {
    shift -= (shift ~/ 32) * 32;
  }
  if (shift < 0) {
    shift += 32;
  }
  if (shift == 0) {
    return ((value >> 1) & 0x7fffffff) * 2 + (value & 1);
  }
  if (value < 0) {
    value = (value >> 1) & 2147483647 | 0x40000000;
    return value >> (shift - 1);
  }
  return value >> shift;
}
