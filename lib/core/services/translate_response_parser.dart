import 'dart:convert';

import '../models/translation_result.dart';

/// Decodes the bare JSON array Google's `translate_a/single` answers with.
///
/// Layout (`dt=t,bd,at`):
/// ```text
///   data[0] = [[translatedSegment, sourceSegment, ...], ...]
///   data[1] = [[pos, [words...], [[word, [backTranslations...]], ...],
///               sourceWord, posIndex], ...]   (null if no dictionary)
///   data[2] = detected source language code
///   data[5] = [[sourceSegment, null, [[alt, ...], ...], ...], ...]
/// ```
abstract final class TranslateResponseParser {
  static TranslationResult parseBody(
    String body, {
    required String requestedFrom,
  }) {
    return parse(
      jsonDecode(body) as List<dynamic>,
      requestedFrom: requestedFrom,
    );
  }

  static TranslationResult parse(
    List<dynamic> data, {
    required String requestedFrom,
  }) {
    final segments = data[0] as List<dynamic>;
    final text = segments
        .map((s) => (s as List<dynamic>).first)
        .whereType<String>()
        .join()
        .trim();

    var detected = requestedFrom;
    final code = data.length > 2 ? data[2] : null;
    if (code is String && code.isNotEmpty) {
      detected = code;
    }

    return TranslationResult(
      text: text,
      alternatives: _alternatives(data),
      detectedSourceLanguage: detected,
      dictionary: _dictionary(data),
    );
  }

  static List<DictionaryEntry> _dictionary(List<dynamic> data) {
    final dictionary = <DictionaryEntry>[];
    if (data.length > 1 && data[1] is List) {
      for (final block in data[1] as List<dynamic>) {
        try {
          final b = block as List<dynamic>;
          final words = <DictionaryWord>[];
          for (final w in b[2] as List<dynamic>) {
            final wl = w as List<dynamic>;
            words.add(
              DictionaryWord(
                word: wl[0] as String,
                backTranslations: wl.length > 1 && wl[1] is List
                    ? (wl[1] as List<dynamic>).whereType<String>().toList()
                    : const [],
              ),
            );
          }
          dictionary.add(DictionaryEntry(pos: b[0] as String, words: words));
        } catch (_) {
          // Skip a block with an unexpected shape rather than fail the whole
          // translation.
        }
      }
    }
    return dictionary;
  }

  static List<String> _alternatives(List<dynamic> data) {
    final alternatives = <String>[];
    try {
      if (data.length > 5 && data[5] is List) {
        for (final seg in data[5] as List<dynamic>) {
          final alts = (seg as List<dynamic>)[2] as List<dynamic>;
          for (final a in alts) {
            final s = (a as List<dynamic>)[0];
            if (s is String && s.trim().isNotEmpty) alternatives.add(s.trim());
          }
        }
      }
    } catch (_) {
      // Alternatives are optional.
    }
    return alternatives;
  }
}
