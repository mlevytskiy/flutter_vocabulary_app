import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/translation_result.dart';
import 'translate_response_parser.dart';

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => message;
}

/// Google Translate's undocumented `translate_a/single` endpoint -- the one
/// the `translator` package wraps, called directly so we control the `dt`
/// flags and get more than a single string back.
///
/// `dt=t` is the plain translation, `dt=bd` the dictionary block (the
/// alternatives grouped by part of speech that the Translation dots popup
/// shows), `dt=at` the ranked alternatives. One request brings all three, so
/// the popup never needs a second call -- see
/// docs/lightning_icon_rules.md.
class GoogleTranslateService {
  static const _host = 'translate.googleapis.com';
  static const _path = '/translate_a/single';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;

  GoogleTranslateService({http.Client? client})
      : _client = client ?? http.Client();

  /// One raw translation. [from] may be `auto`.
  Future<TranslationResult> translate(
    String text, {
    required String to,
    String from = 'auto',
  }) async {
    final uri = Uri.https(_host, _path, {
      'client': 'gtx',
      'sl': from,
      'tl': to,
      'dj': '0',
      'ie': 'UTF-8',
      'oe': 'UTF-8',
      'dt': const ['t', 'bd', 'at'],
      'q': text,
    });

    http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw TranslationException('The request timed out, please try again');
    } catch (e) {
      throw TranslationException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw TranslationException('Request failed (status ${response.statusCode})');
    }

    try {
      // Google answers in UTF-8 but without a charset in the content type, so
      // `response.body` would decode it as latin-1 and mangle Cyrillic.
      return TranslateResponseParser.parseBody(
        utf8.decode(response.bodyBytes),
        requestedFrom: from,
      );
    } catch (e) {
      throw TranslationException('Unexpected response: $e');
    }
  }

  /// [translate] with the part-of-speech rule applied: prefer a noun, then a
  /// verb, adjective, adverb, then any other group; with no dictionary data
  /// fall back to the plain translation.
  ///
  /// Within the chosen group the candidate is the first of Google's own
  /// ranked translations that belongs to the group. For nouns, when none of
  /// them does (e.g. "home" -> "додому", an adverb), the word is
  /// re-translated with an article ("the home" -> "будинок", "домівка") and
  /// those ranked results are tried too. If nothing matches, the group's
  /// first entry wins.
  Future<WordTranslation> translateWord(
    String word, {
    required String to,
    String from = 'en',
  }) async {
    final result = await translate(word, to: to, from: from);
    if (!result.hasDictionary) {
      return WordTranslation(result: result, best: result.text);
    }

    final group = result.dictionaryByPriority.first;

    for (final candidate in result.rankedCandidates) {
      if (group.contains(candidate)) {
        return WordTranslation(
          result: result,
          best: candidate,
          bestPos: group.pos,
        );
      }
    }

    if (group.pos == 'noun' && from == 'en') {
      try {
        final withArticle = await translate('the $word', to: to, from: from);
        for (final candidate in withArticle.rankedCandidates) {
          if (group.contains(candidate)) {
            return WordTranslation(
              result: result,
              best: candidate,
              bestPos: group.pos,
            );
          }
        }
      } on TranslationException catch (_) {
        // The article lookup is only a ranking hint; ignore failures.
      }
    }

    return WordTranslation(
      result: result,
      best: group.words.first.word,
      bestPos: group.pos,
    );
  }
}
