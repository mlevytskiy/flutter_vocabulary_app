import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// Why a talk turn gave no usable answer (learn-redesign AC-24, ADR-0007).
/// [dayLimit] comes only from a start: a reply is never refused for it.
enum TalkApiError { dayLimit, failed, network }

class TalkApiException implements Exception {
  final TalkApiError error;
  final String message;
  TalkApiException(this.error, this.message);

  @override
  String toString() => 'TalkApiException(${error.name}): $message';
}

/// A talk word sent to the Worker: its translation fixes the sense.
typedef TalkWord = ({String word, String translation});

/// One line of the talk so far, as the Worker reads it: [role] is "ai" or
/// "learner".
class TalkLine {
  const TalkLine({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, String> toJson() => {'role': role, 'text': text};
}

/// The Worker's answer to a turn: the AI's [reply] and the word it now steers
/// toward ([target]; it moves on once the learner's last line used it).
class TalkTurn {
  const TalkTurn({required this.reply, required this.target});

  final String reply;
  final String target;
}

/// The app's side of the Worker's talk route `POST /learn/talk` (ADR-0007),
/// behind the app secret like every other app-only route (AC-23). Transport
/// failures, refusals and unexpected answers throw [TalkApiException].
class TalkApiService {
  /// The Worker gives up on its AI at 12 s, so its error arrives first.
  static const turnTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Duration _timeout;

  TalkApiService({http.Client? client, Duration timeout = TalkApiService.turnTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'x-app-secret': VocabApiConfig.appSecret,
      };

  Future<TalkTurn> _post(Map<String, Object> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('${VocabApiConfig.baseUrl}/learn/talk'), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw TalkApiException(TalkApiError.network, 'no answer within ${_timeout.inSeconds} s');
    } catch (e) {
      throw TalkApiException(TalkApiError.network, '$e');
    }
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // An unreadable body is handled below by its status.
    }
    if (response.statusCode == 200 && json != null) {
      final (reply, target) = (json['reply'], json['target']);
      if (reply is String && target is String) return TalkTurn(reply: reply, target: target);
      throw TalkApiException(TalkApiError.failed, 'unexpected answer');
    }
    final code = json?['code'];
    debugPrint('talk api: status ${response.statusCode} ${code ?? ''}');
    final error = response.statusCode == 429 && code == 'day_limit' ? TalkApiError.dayLimit : TalkApiError.failed;
    throw TalkApiException(error, 'status ${response.statusCode}');
  }

  List<Map<String, String>> _words(List<TalkWord> words) => [
        for (final w in words) {'word': w.word, 'translation': w.translation},
      ];

  /// Opens a talk: takes one of the day's talks on the Worker (20 a day
  /// app-wide), so this is the only call that can end in [TalkApiError.dayLimit].
  Future<TalkTurn> start({required String scene, required List<TalkWord> words, required String target}) => _post({
        'kind': 'start',
        'scene': scene,
        'words': _words(words),
        'target': target,
        'history': const <Object>[],
      });

  /// The AI's answer to the learner's last line; [history] (1–24 lines) ends
  /// with that line.
  Future<TalkTurn> reply({
    required String scene,
    required List<TalkWord> words,
    required String target,
    required List<TalkLine> history,
  }) =>
      _post({
        'kind': 'reply',
        'scene': scene,
        'words': _words(words),
        'target': target,
        'history': [for (final l in history) l.toJson()],
      });
}
