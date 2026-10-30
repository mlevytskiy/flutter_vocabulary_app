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

/// The topic chosen in the Learn flow's warm-up (learn-welcome AC-02, AC-13):
/// a prepared topic's [id], or none for the learner's own [text].
typedef TalkTopic = ({String? id, String text});

/// One line of the talk so far, as the Worker reads it: [role] is "ai" or
/// "learner".
class TalkLine {
  const TalkLine({required this.role, required this.text, this.isChoice = false});

  final String role;
  final String text;

  final bool isChoice;

  Map<String, String> toJson() => {'role': role, 'text': text, if (isChoice) 'source': 'choice'};
}

/// The mission a talk plays out (talk-mission, owner 2026-10-24), planned by
/// the Worker at the start. [title], [role] and [goal] are shown; [brief]
/// (the character and the hidden facts) never is: it goes back as the scene
/// of every reply. [words] are the 4–6 talk words it is built on and
/// [picture] is the opening picture's prompt.
class TalkMission {
  const TalkMission({
    required this.title,
    required this.role,
    required this.goal,
    required this.brief,
    required this.words,
    required this.picture,
  });

  final String title;
  final String role;
  final String goal;
  final String brief;
  final List<String> words;
  final String picture;

  /// The mission in [json], or null when a field is missing.
  static TalkMission? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final (title, role, goal, brief, words, picture) =
        (json['title'], json['role'], json['goal'], json['brief'], json['words'], json['picture']);
    if (title is! String || role is! String || goal is! String || brief is! String || picture is! String) return null;
    if (words is! List || words.isEmpty) return null;
    return TalkMission(
      title: title,
      role: role,
      goal: goal,
      brief: brief,
      words: [
        for (final w in words)
          if (w is String) w
      ],
      picture: picture,
    );
  }
}

/// The Worker's answer to a turn: the AI's [reply] and the word it now steers
/// toward ([target]; it moves on once the learner's last line used it). A
/// start also brings the [mission].
class TalkTurn {
  const TalkTurn(
      {required this.reply,
      required this.target,
      this.mission,
      this.interaction,
      this.choices = const [],
      this.speakingPrompt = ''});

  final String reply;
  final String target;
  final TalkMission? mission;

  /// Null for older Workers; otherwise choice, speak or complete.
  final String? interaction;
  final List<String> choices;
  final String speakingPrompt;
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
      if (reply is String && target is String) {
        final interaction = json['interaction'];
        final rawChoices = json['choices'];
        final prompt = json['speakingPrompt'];
        if (interaction != null &&
            (interaction != 'choice' && interaction != 'speak' && interaction != 'complete' ||
                interaction == 'choice' &&
                    (rawChoices is! List ||
                        rawChoices.length < 2 ||
                        rawChoices.length > 3 ||
                        rawChoices.any((c) => c is! String || c.trim().isEmpty || c.length > 80)) ||
                interaction == 'speak' && (prompt is! String || prompt.trim().isEmpty))) {
          throw TalkApiException(TalkApiError.failed, 'invalid interaction');
        }
        return TalkTurn(
            reply: reply,
            target: target,
            mission: TalkMission.fromJson(json['mission']),
            interaction: interaction as String?,
            choices: interaction == 'choice' ? (rawChoices as List).cast<String>() : const [],
            speakingPrompt: prompt is String ? prompt : '');
      }
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

  /// The Learn flow's main dialog (learn-welcome AC-13): the chosen [topic]
  /// and the reply limit (6 or 12), sent on every call of that talk.
  Map<String, Object> _flow(TalkTopic? topic, int? maxReplies) => {
        if (topic != null) 'topic': {if (topic.id != null) 'id': topic.id!, 'text': topic.text},
        if (maxReplies != null) 'maxReplies': maxReplies,
      };

  /// Opens a talk: takes one of the day's talks on the Worker (20 a day
  /// app-wide), so this is the only call that can end in [TalkApiError.dayLimit].
  /// [scene] is only the topic the Worker plans the mission from. With
  /// [maxReplies] (the Learn flow's main dialog) the mission is built on
  /// exactly [words], in that order, within [topic].
  Future<TalkTurn> start({
    required String scene,
    required List<TalkWord> words,
    required String target,
    TalkTopic? topic,
    int? maxReplies,
  }) =>
      _post({
        'kind': 'start',
        'mode': 'mixed',
        'scene': scene,
        'words': _words(words),
        'target': target,
        'history': const <Object>[],
        ..._flow(topic, maxReplies),
      });

  /// The AI's answer to the learner's last line; [history] (1–24 lines) ends
  /// with that line.
  Future<TalkTurn> reply({
    required String scene,
    required List<TalkWord> words,
    required String target,
    required List<TalkLine> history,
    TalkTopic? topic,
    int? maxReplies,
  }) =>
      _post({
        'kind': 'reply',
        'mode': 'mixed',
        'scene': scene,
        'words': _words(words),
        'target': target,
        'history': [for (final l in history) l.toJson()],
        ..._flow(topic, maxReplies),
      });
}
