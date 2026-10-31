import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// The Worker's free `POST /learn/warm-up/reaction` (learn-warm-up-v2 AC-05,
/// AC-12, ADR-0003): one friendly line after a warm-up answer. One try, no
/// retry, a 2 s cutoff; a failure, a late or empty reply gives one of the
/// [fixedLines] at random, and a later reply is dropped. Never throws. The
/// answer is never logged.
class WarmUpReactionService {
  static const defaultTimeout = Duration(seconds: 2);
  static const maxAnswerLength = 80;

  /// The warm-up questions that get a reaction (the Worker's list).
  static const questions = {'intro', 'mood', 'goal', 'daily', 'grammar'};

  /// The fixed lines (AC-05), picked at random.
  static const fixedLines = <String>[
    'Got it, thanks!',
    'Nice, good to know.',
    "Great, let's go on.",
    'Thanks, that helps!',
    'Sounds good!',
    'Cool, thanks for sharing.',
  ];

  final http.Client _client;
  final Duration _timeout;
  final Random _random;

  WarmUpReactionService(
      {http.Client? client, Duration timeout = defaultTimeout, Random? random})
      : _client = client ?? http.Client(),
        _timeout = timeout,
        _random = random ?? Random();

  String get fixedLine => fixedLines[_random.nextInt(fixedLines.length)];

  /// The reaction to [answer] given to [question] (one of [questions]), or a
  /// fixed line. An unknown question or a blank or over-80 answer sends nothing.
  Future<String> react(String question, String answer) async {
    final sent = answer.trim();
    if (!questions.contains(question) ||
        sent.isEmpty ||
        sent.length > maxAnswerLength) {
      return fixedLine;
    }
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/learn/warm-up/reaction'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'question': question, 'answer': sent}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('VOCAB: /learn/warm-up/reaction: status '
            '${response.statusCode}');
        return fixedLine;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final reaction = decoded is Map<String, dynamic> ? decoded['reaction'] : null;
      if (reaction is! String || reaction.trim().isEmpty) return fixedLine;
      return reaction.trim();
    } catch (e) {
      debugPrint('VOCAB: /learn/warm-up/reaction failed: ${e.runtimeType}');
      return fixedLine;
    }
  }
}
