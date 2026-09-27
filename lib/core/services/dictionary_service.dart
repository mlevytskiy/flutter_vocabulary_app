import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/definition_result.dart';

/// Asks the Worker's dictionary route for a word's senses (definition-mode,
/// ADR-0002). The dictionary key lives only in the Worker; the app sends the
/// same shared secret it uses for photos and publishing. Never throws: a
/// timeout, a network error, an old Worker without the route or any
/// unexpected answer is [DefinitionKind.unavailable], so the screen can leave
/// the field as it was and say so (spec AC-07).
class DictionaryService {
  /// sad §8: the Worker gives the dictionary 4 s; the app gives the Worker 6 s.
  static const defaultTimeout = Duration(seconds: 6);

  final http.Client _client;
  final Duration _timeout;

  DictionaryService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  Future<DefinitionResult> define(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return const DefinitionResult.notFound([]);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/define'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'word': trimmed}),
          )
          .timeout(_timeout);
      final result = _parse(response);
      debugPrint('[definition] "$trimmed" ${result.kind.name} '
          'in ${stopwatch.elapsedMilliseconds} ms');
      return result;
    } catch (e) {
      debugPrint('[definition] "$trimmed" unavailable after '
          '${stopwatch.elapsedMilliseconds} ms: $e');
      return const DefinitionResult.unavailable();
    }
  }

  DefinitionResult _parse(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return const DefinitionResult.unavailable();
    }
    if (decoded is! Map || response.statusCode != 200) {
      return const DefinitionResult.unavailable();
    }
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    switch (decoded['outcome']) {
      case 'senses':
        final senses = strings(decoded['senses']);
        return senses.isEmpty
            ? const DefinitionResult.notFound([])
            : DefinitionResult.found(senses);
      case 'not_found':
        return DefinitionResult.notFound(strings(decoded['suggestions']));
      default:
        return const DefinitionResult.unavailable();
    }
  }
}
