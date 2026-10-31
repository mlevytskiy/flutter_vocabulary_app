import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// One topic offered on the Talk welcome page (learn-welcome AC-03), with
/// its one-line situation for this learner (learn-warm-up-v2 AC-13; the
/// catalog's example situation when no line came, "" from an older Worker).
@immutable
class LearnTopic {
  final String id;
  final String title;
  final String description;
  final String situation;

  const LearnTopic(
      {required this.id,
      required this.title,
      required this.description,
      this.situation = ''});

  @override
  bool operator ==(Object other) =>
      other is LearnTopic &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.situation == situation;

  @override
  int get hashCode => Object.hash(id, title, description, situation);
}

/// A topic pick already on its way (learn-warm-up-v2 AC-13): it starts when
/// the main question is answered; [topics] is called on reaching the topic
/// step and waits at most the service's timeout from that call.
class PendingTopics {
  final Future<List<LearnTopic>?> _reply;
  final Duration _timeout;

  PendingTopics._(this._reply, this._timeout);

  /// The three topics, or the bundled three when they are not in within the
  /// timeout counted from this call. Never throws.
  Future<List<LearnTopic>> topics() => _reply
      .timeout(_timeout, onTimeout: () => null)
      .then((t) => t ?? LearnTopicsService.bundled);
}

/// The Worker's `POST /learn/topics` (learn-welcome AC-03): the three topics
/// that fit the card words best. Anything but a good 200 within [timeout]
/// gives the bundled three. Never throws. learn-warm-up-v2 AC-12/AC-13: it
/// also carries the learner profile (level, goal, daily; the only call that
/// does) and this warm-up's mood, and reads each topic's situation line.
class LearnTopicsService {
  static const defaultTimeout = Duration(seconds: 4);
  static const maxWords = 60;
  static const maxProfileField = 80;

  /// The warm-up's mood taps the Worker knows.
  static const moods = {'useful', 'mystery', 'argument', 'surprise'};

  static const bundled = <LearnTopic>[
    LearnTopic(
      id: 'daily-routine',
      title: 'Daily routine',
      description:
          'Talk about how your ordinary day goes from morning to night.',
      situation:
          'A new flatmate asks how your usual weekday goes, from the alarm to bedtime.',
    ),
    LearnTopic(
      id: 'food-and-cooking',
      title: 'Food and cooking',
      description: 'Talk about what you eat, what you cook and where you shop.',
      situation:
          'You and a friend cook dinner together and argue about how much spice to add.',
    ),
    LearnTopic(
      id: 'travel',
      title: 'Travel',
      description:
          'Talk about trips you took, places you want to see and plans.',
      situation:
          'You plan a weekend trip with a friend and choose where to go and how.',
    ),
  ];

  final http.Client _client;
  final Duration _timeout;

  LearnTopicsService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  /// The three best topics for [words] (blank ones skipped, at most 60 sent),
  /// best first; the bundled three on any failure, when there are no words or
  /// when nothing good comes within the timeout from now.
  Future<List<LearnTopic>> pick(List<String> words,
          {String? level, String? goal, String? daily, String? mood}) =>
      start(words, level: level, goal: goal, daily: daily, mood: mood)
          .topics();

  /// Starts the pick now; the timeout counts from [PendingTopics.topics].
  /// Profile fields are trimmed, empty ones dropped, long ones cut to 80; a
  /// mood off [moods] is left out.
  PendingTopics start(List<String> words,
      {String? level, String? goal, String? daily, String? mood}) {
    final sent = [
      for (final w in words)
        if (w.trim().isNotEmpty) w.trim(),
    ].take(maxWords).toList();
    if (sent.isEmpty) return PendingTopics._(Future.value(null), _timeout);
    final profile = <String, String>{
      for (final MapEntry(:key, :value)
          in {'level': level, 'goal': goal, 'daily': daily}.entries)
        if (value != null && value.trim().isNotEmpty)
          key: _cut(value.trim(), maxProfileField),
    };
    final body = {
      'words': sent,
      if (profile.isNotEmpty) 'profile': profile,
      if (mood != null && moods.contains(mood)) 'mood': mood,
    };
    return PendingTopics._(_request(body), _timeout);
  }

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// The three topics, or null on any failure. Never throws; no timeout here.
  Future<List<LearnTopic>?> _request(Map<String, Object> body) async {
    try {
      final response = await _client.post(
        Uri.parse('${VocabApiConfig.baseUrl}/learn/topics'),
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'x-app-secret': VocabApiConfig.appSecret,
        },
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        debugPrint('VOCAB: /learn/topics: status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = decoded is Map<String, dynamic> ? decoded['topics'] : null;
      if (list is! List) return null;
      final topics = <LearnTopic>[];
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) return null;
        final id = raw['id'];
        final title = raw['title'];
        final description = raw['description'];
        final situation = raw['situation'];
        if (id is! String ||
            title is! String ||
            description is! String ||
            id.isEmpty ||
            title.isEmpty) {
          return null;
        }
        topics.add(LearnTopic(
            id: id,
            title: title,
            description: description,
            situation: situation is String ? situation.trim() : ''));
      }
      return topics.length == 3 ? topics : null;
    } catch (e) {
      debugPrint('VOCAB: /learn/topics failed: $e');
      return null;
    }
  }
}
