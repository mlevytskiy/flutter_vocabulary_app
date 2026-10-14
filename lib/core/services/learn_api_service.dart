import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// Why a learn call gave no usable answer (learn-kit S-13). The exercise
/// frame shows one line per error (S-06): [dayLimit] and [rateLimited] have
/// their own; [unavailable] (no LEARN_DATA on the Worker) shows as [failed].
enum LearnApiError { network, timeout, dayLimit, rateLimited, failed, unavailable }

class LearnApiException implements Exception {
  final LearnApiError error;
  final String message;
  LearnApiException(this.error, this.message);

  @override
  String toString() => 'LearnApiException(${error.name}): $message';
}

/// A word sent for exercise data: its translation fixes the sense (D-06).
typedef LearnWord = ({String rowId, String word, String translation});

// One record per data kind (S-13, S-15): what the Worker checked and returns.
typedef SynonymData = ({String synonym});
typedef DefinitionData = ({String definition});
typedef CluesData = ({List<String> clues});
typedef SentenceData = ({String sentence});
typedef PatternData = ({String sentence, String pattern, String usage});
typedef TranslateData = ({String source, String cue, String model});

String? _text(Map<String, dynamic> v, String key) => v[key] is String ? v[key] as String : null;

SynonymData? _synonym(Map<String, dynamic> v) {
  final synonym = _text(v, 'synonym');
  return synonym == null ? null : (synonym: synonym);
}

DefinitionData? _definition(Map<String, dynamic> v) {
  final definition = _text(v, 'definition');
  return definition == null ? null : (definition: definition);
}

CluesData? _clues(Map<String, dynamic> v) {
  final clues = v['clues'];
  if (clues is! List || clues.length != 3 || !clues.every((c) => c is String)) return null;
  return (clues: List<String>.unmodifiable(clues.cast<String>()));
}

SentenceData? _sentence(Map<String, dynamic> v) {
  final sentence = _text(v, 'sentence');
  return sentence == null ? null : (sentence: sentence);
}

PatternData? _pattern(Map<String, dynamic> v) {
  final (sentence, pattern, usage) = (_text(v, 'sentence'), _text(v, 'pattern'), _text(v, 'usage'));
  if (sentence == null || pattern == null || usage == null) return null;
  return (sentence: sentence, pattern: pattern, usage: usage);
}

TranslateData? _translate(Map<String, dynamic> v) {
  final (source, cue, model) = (_text(v, 'source'), _text(v, 'cue'), _text(v, 'model'));
  if (source == null || cue == null || model == null) return null;
  return (source: source, cue: cue, model: model);
}

/// The kinds of exercise data `POST /learn/data` makes (S-14), each typed
/// with its answer record: `fetchData(LearnDataKind.synonym, words)` gives
/// `Map<String, SynonymData?>`.
final class LearnDataKind<T> {
  const LearnDataKind._(this.wire, this._parse);

  /// The Worker's name for the kind.
  final String wire;
  final T? Function(Map<String, dynamic>) _parse;

  static const synonym = LearnDataKind<SynonymData>._('synonym', _synonym);
  static const definition = LearnDataKind<DefinitionData>._('definition', _definition);
  static const clues = LearnDataKind<CluesData>._('clues', _clues);
  static const sentence = LearnDataKind<SentenceData>._('sentence', _sentence);
  static const pattern = LearnDataKind<PatternData>._('pattern', _pattern);
  static const translate = LearnDataKind<TranslateData>._('translate', _translate);

  static const List<LearnDataKind<Object>> values = [synonym, definition, clues, sentence, pattern, translate];
}

/// What a learner's sentence answers (S-20). There is no "story" task.
enum LearnCheckTask { pattern, own, translate, explain }

/// One sentence check: `extra` is the pattern (pattern), the source sentence
/// (translate), or empty (own, explain).
typedef LearnCheckRequest = ({String word, String translation, String sentence, LearnCheckTask task, String extra});

/// The Worker's answer to a check; `usesWord` is the Worker's own match. The
/// app's verdict is `judgeCheck` (S-21), never this alone.
typedef CheckReply = ({bool usesWord, bool usesTask, bool ok, String fixed, String note});

/// The app's side of the Worker's exercise services (learn-kit S-13):
/// `POST /learn/data` and `POST /learn/check`, behind the app secret like
/// every other app-only route. Transport failures, refusals and unexpected
/// answers throw [LearnApiException].
class LearnApiService {
  /// The Worker gives up on its AI at 25 s (data) and 12 s (check), so its
  /// error arrives before these (spec §6).
  static const dataTimeout = Duration(seconds: 30);
  static const checkTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Duration _dataTimeout;
  final Duration _checkTimeout;

  LearnApiService({
    http.Client? client,
    Duration dataTimeout = LearnApiService.dataTimeout,
    Duration checkTimeout = LearnApiService.checkTimeout,
  })  : _client = client ?? http.Client(),
        _dataTimeout = dataTimeout,
        _checkTimeout = checkTimeout;

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'x-app-secret': VocabApiConfig.appSecret,
      };

  Future<Map<String, dynamic>> _post(String path, Object body, Duration timeout) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('${VocabApiConfig.baseUrl}$path'), headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw LearnApiException(LearnApiError.timeout, 'no answer within ${timeout.inSeconds} s');
    } catch (e) {
      throw LearnApiException(LearnApiError.network, '$e');
    }
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // An unreadable body is handled below by its status.
    }
    if (response.statusCode == 200 && json != null) return json;
    final code = json?['code'];
    debugPrint('learn api: $path status ${response.statusCode} ${code ?? ''}');
    final error = switch (response.statusCode) {
      429 => code == 'day_limit' ? LearnApiError.dayLimit : LearnApiError.rateLimited,
      503 when code == 'no_storage' => LearnApiError.unavailable,
      _ => LearnApiError.failed,
    };
    throw LearnApiException(error, 'status ${response.statusCode}');
  }

  /// POST /learn/data: [kind]'s data for each of [words] (1-19), by rowId. A
  /// null value is "no answer" for that word: the exercise leaves it out.
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    final json = await _post(
      '/learn/data',
      {
        'kind': kind.wire,
        'words': [for (final w in words) {'rowId': w.rowId, 'word': w.word, 'translation': w.translation}],
      },
      _dataTimeout,
    );
    final results = json['results'];
    if (results is! List) throw LearnApiException(LearnApiError.failed, 'unexpected answer: no results');
    return {
      for (final r in results)
        if (r is Map<String, dynamic> && r['rowId'] is String)
          r['rowId'] as String: r['value'] is Map<String, dynamic> ? kind._parse(r['value'] as Map<String, dynamic>) : null,
    };
  }

  /// POST /learn/check: one learner sentence, never cached (S-20).
  Future<CheckReply> check(LearnCheckRequest request) async {
    final json = await _post(
      '/learn/check',
      {
        'word': request.word,
        'translation': request.translation,
        'sentence': request.sentence,
        'task': request.task.name,
        'extra': request.extra,
      },
      _checkTimeout,
    );
    final (usesWord, usesTask, ok) = (json['usesWord'], json['usesTask'], json['ok']);
    if (usesWord is! bool || usesTask is! bool || ok is! bool) {
      throw LearnApiException(LearnApiError.failed, 'unexpected answer');
    }
    return (
      usesWord: usesWord,
      usesTask: usesTask,
      ok: ok,
      fixed: json['fixed'] is String ? json['fixed'] as String : '',
      note: json['note'] is String ? json['note'] as String : '',
    );
  }
}
