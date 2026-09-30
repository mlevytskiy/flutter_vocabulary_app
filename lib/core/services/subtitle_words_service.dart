import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
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

  SubtitleWordsResult({
    required this.words,
    required this.model,
    required this.aiDuration,
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// Asks the Worker's POST /subtitles/words to pick words from a subtitle
/// file's dialogue lines (words-from-subtitles, contracts/openapi.yaml). A
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
    required List<String> lines,
    required ImportPurpose purpose,
    required EnglishLevel level,
    required int maximum,
    required SubtitleModel model,
    required List<String> sessionWords,
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
              'lines': lines,
              'purpose': purpose.wire,
              'level': level.wire,
              'maximum': maximum,
              'model': model.id,
              'sessionWords': sessionWords,
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
      );
    } catch (e) {
      throw SubtitleWordsException(SubtitleWordsError.notPicked, 'unexpected answer: $e');
    }
  }
}
