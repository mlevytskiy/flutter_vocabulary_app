import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/offered_ai.dart';
import '../models/word_group.dart';
import '../story/word_grouping.dart';

/// Why a call to the story routes gave no usable answer.
enum StoryApiError { network, timeout, rateLimited, groupingFailed, unexpected }

class StoryApiException implements Exception {
  final StoryApiError error;
  final String message;
  StoryApiException(this.error, this.message);

  @override
  String toString() => 'StoryApiException(${error.name}): $message';
}

/// The Worker's refusals of a run start or a redo (T9 codes).
enum StoryRefusal {
  /// 422 not_offered: the AI is not on the offered list (AC-13).
  notOffered,

  /// 429 day_limit: today's story allowance is used up (AC-19).
  dayLimit,

  /// Any other 429: the Worker's request rate limit.
  rateLimited,

  /// 404 unknown_run.
  unknownRun,

  /// 409 not_failed: the step has not failed (or a repeated tap).
  notFailed,

  /// 503 no_storage: the Worker has no picture storage.
  unavailable,
}

sealed class StoryActionResult {
  const StoryActionResult();
}

/// The run (or redo) was accepted. [attempt] is the new picture attempt of a
/// "Draw again".
class StoryStarted extends StoryActionResult {
  final int? attempt;
  const StoryStarted({this.attempt});
}

class StoryRefused extends StoryActionResult {
  final StoryRefusal reason;

  /// The AI id that was refused, for [StoryRefusal.notOffered].
  final String? model;
  const StoryRefused(this.reason, {this.model});
}

/// One step of a run as the Worker reports it.
class StepStatus {
  final String role;
  final int attempt;
  final String modelId;
  final String outcome;
  final String? text;
  final List<String> missedWords;
  final String? pictureKey;
  final double? priceUsd;
  final bool priceEstimated;
  final int? ms;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const StepStatus({
    required this.role,
    required this.attempt,
    required this.modelId,
    required this.outcome,
    this.text,
    this.missedWords = const [],
    this.pictureKey,
    this.priceUsd,
    this.priceEstimated = false,
    this.ms,
    this.startedAt,
    this.finishedAt,
  });

  factory StepStatus.fromJson(Map<String, dynamic> json) => StepStatus(
        role: json['role'] as String,
        attempt: json['attempt'] as int,
        modelId: json['modelId'] as String,
        outcome: json['outcome'] as String,
        text: json['text'] as String?,
        missedWords: [...(json['missedWords'] as List<dynamic>? ?? const []).cast<String>()],
        pictureKey: json['pictureKey'] as String?,
        priceUsd: (json['priceUsd'] as num?)?.toDouble(),
        priceEstimated: json['priceEstimated'] as bool? ?? false,
        ms: json['ms'] as int?,
        startedAt: _time(json['startedAt']),
        finishedAt: _time(json['finishedAt']),
      );
}

/// One run as the Worker reports it: its words, the three AIs and the steps so far.
class RunStatus {
  final String runId;
  final List<String> words;
  final String storyModel;
  final String promptModel;
  final String pictureModel;
  final DateTime? createdAt;
  final List<StepStatus> steps;

  const RunStatus({
    required this.runId,
    required this.words,
    required this.storyModel,
    required this.promptModel,
    required this.pictureModel,
    required this.createdAt,
    required this.steps,
  });

  factory RunStatus.fromJson(Map<String, dynamic> json) => RunStatus(
        runId: json['runId'] as String,
        words: [...(json['words'] as List<dynamic>).cast<String>()],
        storyModel: json['storyModel'] as String,
        promptModel: json['promptModel'] as String,
        pictureModel: json['pictureModel'] as String,
        createdAt: _time(json['createdAt']),
        steps: [
          for (final s in json['steps'] as List<dynamic>) StepStatus.fromJson(s as Map<String, dynamic>),
        ],
      );
}

DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// The app's side of the Worker's story routes (mnemonic-story T7, T9): the
/// offered AI list, grouping, starting and redoing runs, polling their steps
/// and fetching a run's picture. Behind the app secret like every other route.
/// Transport failures and unexpected answers throw [StoryApiException]; the
/// Worker's refusals come back as a [StoryRefused] result.
class StoryApiService {
  static const defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Duration _timeout;

  StoryApiService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'x-app-secret': VocabApiConfig.appSecret,
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${VocabApiConfig.baseUrl}$path').replace(queryParameters: query);

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw StoryApiException(StoryApiError.timeout, 'no answer within ${_timeout.inSeconds} s');
    } catch (e) {
      throw StoryApiException(StoryApiError.network, '$e');
    }
  }

  Map<String, dynamic>? _json(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  StoryApiException _failed(http.Response response) {
    debugPrint('story api: status ${response.statusCode} ${response.body}');
    return StoryApiException(
      response.statusCode == 429 ? StoryApiError.rateLimited : StoryApiError.unexpected,
      'status ${response.statusCode}',
    );
  }

  /// GET /story/models.
  Future<OfferedAiList> offeredAis() async {
    final response = await _send(() => _client.get(_uri('/story/models'), headers: _headers));
    if (response.statusCode != 200) throw _failed(response);
    try {
      return OfferedAiList.fromJson(_json(response)!);
    } catch (e) {
      throw StoryApiException(StoryApiError.unexpected, 'unexpected answer: $e');
    }
  }

  /// POST /story/grouping: the fixed AI's split of [words], keeping [keep].
  Future<List<SplitGroup>> group(List<GroupingWord> words, List<WordGroup> keep) async {
    final response = await _send(() => _client.post(
          _uri('/story/grouping'),
          headers: _headers,
          body: jsonEncode({
            'words': [for (final w in words) {'rowId': w.rowId, 'word': w.word}],
            if (keep.isNotEmpty)
              'keep': [for (final g in keep) {'id': g.id, 'name': g.name, 'rowIds': g.rowIds}],
          }),
        ));
    if (response.statusCode == 502) {
      throw StoryApiException(StoryApiError.groupingFailed, 'status 502');
    }
    if (response.statusCode != 200) throw _failed(response);
    try {
      return [
        for (final g in _json(response)!['groups'] as List<dynamic>)
          SplitGroup.fromJson(g as Map<String, dynamic>),
      ];
    } catch (e) {
      throw StoryApiException(StoryApiError.unexpected, 'unexpected answer: $e');
    }
  }

  /// POST /story/runs.
  Future<StoryActionResult> startRun({
    required String runId,
    required List<String> words,
    required String storyModel,
    required String promptModel,
    required String pictureModel,
  }) async {
    final response = await _send(() => _client.post(
          _uri('/story/runs'),
          headers: _headers,
          body: jsonEncode({
            'runId': runId,
            'words': words,
            'storyModel': storyModel,
            'promptModel': promptModel,
            'pictureModel': pictureModel,
          }),
        ));
    return _action(response);
  }

  /// GET /story/runs?ids=...: the steps so far of the given runs. A run the
  /// Worker does not know is left out.
  Future<List<RunStatus>> status(List<String> runIds) async {
    if (runIds.isEmpty) return const [];
    final response = await _send(() => _client.get(_uri('/story/runs', {'ids': runIds.join(',')}), headers: _headers));
    if (response.statusCode != 200) throw _failed(response);
    try {
      return [
        for (final r in _json(response)!['runs'] as List<dynamic>) RunStatus.fromJson(r as Map<String, dynamic>),
      ];
    } catch (e) {
      throw StoryApiException(StoryApiError.unexpected, 'unexpected answer: $e');
    }
  }

  /// POST /story/runs/redo: [step] is 'prompt' or 'picture' ("Draw again",
  /// optionally with another [pictureModel]).
  Future<StoryActionResult> redo({required String runId, required String step, String? pictureModel}) async {
    final response = await _send(() => _client.post(
          _uri('/story/runs/redo'),
          headers: _headers,
          body: jsonEncode({
            'runId': runId,
            'step': step,
            if (pictureModel != null) 'pictureModel': pictureModel,
          }),
        ));
    return _action(response);
  }

  /// GET /story/runs/<runId>/pictures/<attempt>: the picture bytes, or null
  /// once the Worker no longer holds them (collected, or older than 7 days).
  Future<Uint8List?> picture(String runId, int attempt) async {
    final response = await _send(() => _client.get(_uri('/story/runs/$runId/pictures/$attempt'), headers: _headers));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw _failed(response);
    return response.bodyBytes;
  }

  StoryActionResult _action(http.Response response) {
    final body = _json(response);
    final code = body?['code'] as String?;
    switch (response.statusCode) {
      case 200:
        if (body?['started'] != true) {
          throw StoryApiException(StoryApiError.unexpected, 'not started: ${response.body}');
        }
        return StoryStarted(attempt: body?['attempt'] as int?);
      case 404 when code == 'unknown_run':
        return const StoryRefused(StoryRefusal.unknownRun);
      case 409 when code == 'not_failed':
        return const StoryRefused(StoryRefusal.notFailed);
      case 422 when code == 'not_offered':
        return StoryRefused(StoryRefusal.notOffered, model: body?['model'] as String?);
      case 429:
        return StoryRefused(code == 'day_limit' ? StoryRefusal.dayLimit : StoryRefusal.rateLimited);
      case 503 when code == 'no_storage':
        return const StoryRefused(StoryRefusal.unavailable);
    }
    throw _failed(response);
  }
}
