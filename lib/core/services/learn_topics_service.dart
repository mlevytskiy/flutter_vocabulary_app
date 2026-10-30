import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// One topic offered on the Talk welcome page (learn-welcome AC-03).
@immutable
class LearnTopic {
  final String id;
  final String title;
  final String description;

  const LearnTopic(
      {required this.id, required this.title, required this.description});

  @override
  bool operator ==(Object other) =>
      other is LearnTopic &&
      other.id == id &&
      other.title == title &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, title, description);
}

/// The Worker's `POST /learn/topics` (learn-welcome AC-03): the three topics
/// that fit the card words best. Anything but a good 200 within [timeout]
/// gives the bundled three. Never throws.
class LearnTopicsService {
  static const defaultTimeout = Duration(seconds: 4);
  static const maxWords = 60;

  static const bundled = <LearnTopic>[
    LearnTopic(
      id: 'daily-routine',
      title: 'Daily routine',
      description:
          'Talk about how your ordinary day goes from morning to night.',
    ),
    LearnTopic(
      id: 'food-and-cooking',
      title: 'Food and cooking',
      description: 'Talk about what you eat, what you cook and where you shop.',
    ),
    LearnTopic(
      id: 'travel',
      title: 'Travel',
      description:
          'Talk about trips you took, places you want to see and plans.',
    ),
  ];

  final http.Client _client;
  final Duration _timeout;

  LearnTopicsService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  /// The three best topics for [words] (blank ones skipped, at most 60 sent),
  /// best first; the bundled three on any failure or when there are no words.
  Future<List<LearnTopic>> pick(List<String> words) async {
    final sent = [
      for (final w in words)
        if (w.trim().isNotEmpty) w.trim(),
    ].take(maxWords).toList();
    if (sent.isEmpty) return bundled;
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/learn/topics'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'words': sent}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('VOCAB: /learn/topics: status ${response.statusCode}');
        return bundled;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = decoded is Map<String, dynamic> ? decoded['topics'] : null;
      if (list is! List) return bundled;
      final topics = <LearnTopic>[];
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) return bundled;
        final id = raw['id'];
        final title = raw['title'];
        final description = raw['description'];
        if (id is! String ||
            title is! String ||
            description is! String ||
            id.isEmpty ||
            title.isEmpty) {
          return bundled;
        }
        topics.add(LearnTopic(id: id, title: title, description: description));
      }
      return topics.length == 3 ? topics : bundled;
    } catch (e) {
      debugPrint('VOCAB: /learn/topics failed: $e');
      return bundled;
    }
  }
}
