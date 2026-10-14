import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../dialogues/dialogue_rules.dart' show ImportedDialogue;
import '../models/subtitle_import_options.dart';
import '../models/vocab_word.dart';

/// The three ways a subtitle import can fail, each with its own message
/// (api-sync-report.md App error mapping).
enum SubtitleWordsError {
  /// 422: the model found no English dialogue (AC-10).
  noEnglish,

  /// Any 429: over the import allowance or the rate limit (AC-14).
  tooManyImports,

  /// Everything else, including no connection and no answer in time (AC-12).
  notPicked,
}

class SubtitleWordsException implements Exception {
  final SubtitleWordsError error;
  final String detail;
  SubtitleWordsException(this.error, this.detail);

  @override
  String toString() => 'SubtitleWordsException(${error.name}): $detail';
}

class SubtitleWordsResult {
  final List<VocabWord> words;
  final SubtitleModel model;

  /// Time the Worker spent on the AI call.
  final Duration aiDuration;
  final int inputTokens;
  final int outputTokens;

  /// The film dialogues the Worker kept, each with the returned words it
  /// holds (get-words-from-subtitles-improvment); empty when none were asked
  /// for or none qualified.
  final List<ImportedDialogue> dialogues;

  SubtitleWordsResult({
    required this.words,
    required this.model,
    required this.aiDuration,
    required this.inputTokens,
    required this.outputTokens,
    this.dialogues = const [],
  });
}

/// Asks the Worker's POST /subtitles/words to translate the words the phone
/// picked from a subtitle file ([SubtitleWordCounter]), sent as JSON with one
/// context line each — never the file. With dialogues asked, the excerpts
/// around the words' places go too (words-from-subtitles, contracts/openapi.yaml). A
/// response is complete or a [SubtitleWordsException] — never a partial list.
class SubtitleWordsService {
  /// sad §4: the Worker aborts its AI call at 225 s, so it answers first.
  static const defaultTimeout = Duration(seconds: 240);

  final http.Client _client;
  final Duration _timeout;

  SubtitleWordsService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  Future<SubtitleWordsResult> pickWords({
    required List<String> words,
    required Map<String, String> contexts,
    required List<String> lines,
    required int maximum,
    required SubtitleModel model,
    required List<String> sessionWords,
    bool dialogues = false,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/subtitles/words'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({
              'words': [
                for (final word in words) {'word': word, 'context': contexts[word] ?? ''},
              ],
              'maximum': maximum,
              'model': model.id,
              'sessionWords': sessionWords,
              // Off sends no dialogues key and no lines (AC-01).
              if (dialogues) 'dialogues': true,
              if (dialogues) 'lines': lines,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw SubtitleWordsException(SubtitleWordsError.notPicked, 'no answer within ${_timeout.inSeconds} s');
    } catch (e) {
      throw SubtitleWordsException(SubtitleWordsError.notPicked, 'network error: $e');
    }

    if (response.statusCode == 422) {
      throw SubtitleWordsException(SubtitleWordsError.noEnglish, 'status 422');
    }
    if (response.statusCode == 429) {
      throw SubtitleWordsException(SubtitleWordsError.tooManyImports, 'status 429');
    }
    if (response.statusCode != 200) {
      debugPrint('subtitle words: status ${response.statusCode} ${response.body}');
      throw SubtitleWordsException(SubtitleWordsError.notPicked, 'status ${response.statusCode}');
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final model = SubtitleModel.byId(decoded['model'] as String);
      if (model == null) throw const FormatException('unknown model');
      final usage = decoded['usage'] as Map<String, dynamic>;
      return SubtitleWordsResult(
        words: (decoded['words'] as List<dynamic>)
            .map((item) => VocabWord.fromJson(item as Map<String, dynamic>))
            .toList(),
        model: model,
        aiDuration: Duration(milliseconds: (decoded['timings'] as Map<String, dynamic>)['aiMs'] as int),
        inputTokens: usage['inputTokens'] as int,
        outputTokens: usage['outputTokens'] as int,
        // An older Worker sends none (AC-07); a cut-off list fails the whole
        // reply (AC-08).
        dialogues: [
          for (final item in decoded['dialogues'] as List<dynamic>? ?? const [])
            (
              lines: [...((item as Map<String, dynamic>)['lines'] as List<dynamic>).cast<String>()],
              words: [...(item['words'] as List<dynamic>).cast<String>()],
            ),
        ],
      );
    } catch (e) {
      throw SubtitleWordsException(SubtitleWordsError.notPicked, 'unexpected answer: $e');
    }
  }
}
