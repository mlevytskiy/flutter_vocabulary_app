import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/collection_name.dart'
    show cleanAutoDescription, cleanAutoName;
import '../models/word_pair.dart';

/// The Worker's `POST /collections/name` and `POST /collections/description`
/// (collection-naming, owner 2026-10-18): a short name, or a one- or
/// two-sentence description, for a collection's words, from Sonnet 5.5
/// unless [model] says otherwise. Behind the app secret like every other route.
class CollectionNamingService {
  static const defaultModel = 'claude-sonnet-5-5';
  static const defaultTimeout = Duration(seconds: 40);

  /// The most words sent; the Worker refuses more.
  static const maxWords = 50;

  final http.Client _client;
  final Duration _timeout;
  final String model;

  CollectionNamingService({
    http.Client? client,
    Duration timeout = defaultTimeout,
    this.model = defaultModel,
  })  : _client = client ?? http.Client(),
        _timeout = timeout;

  /// The AI's name for [words] (blank rows skipped), or null when there is
  /// none to be had: offline, a refusal, an answer that cannot be a name.
  /// Never throws.
  Future<String?> nameFor(List<WordPair> words) =>
      _ask('/collections/name', 'name', cleanAutoName, words);

  /// The AI's description for [words], as [nameFor]. Never throws.
  Future<String?> descriptionFor(List<WordPair> words) => _ask(
      '/collections/description', 'description', cleanAutoDescription, words);

  /// Waits longer: one answer for up to 100 collections.
  static const autofillTimeout = Duration(seconds: 150);

  /// `POST /collections/autofill`: names and descriptions for many
  /// collections in one request (the upgrade of collections from before
  /// collection-naming). [items] are (id, words, want a name, want a
  /// description). Answers by id, each cleaned like the single answers; null
  /// when the request failed. Never throws.
  Future<Map<String, ({String? name, String? description})>?> autofill(
      List<({String id, List<WordPair> words, bool name, bool description})>
          items) async {
    final sent = [
      for (final i in items)
        {
          'id': i.id,
          'words': _words(i.words).take(30).toList(),
          'want': [if (i.name) 'name', if (i.description) 'description'],
        },
    ];
    if (sent.isEmpty) return const {};
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/collections/autofill'),
            headers: _headers,
            body: jsonEncode({'collections': sent, 'model': model}),
          )
          .timeout(autofillTimeout);
      if (response.statusCode != 200) {
        debugPrint('VOCAB: autofill: status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list =
          decoded is Map<String, dynamic> ? decoded['collections'] : null;
      if (list is! List) return null;
      final asked = {for (final i in items) i.id: i};
      final answers = <String, ({String? name, String? description})>{};
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final item = asked[raw['id']];
        if (item == null) continue;
        final name = raw['name'];
        final description = raw['description'];
        final answer = (
          name: item.name && name is String ? cleanAutoName(name) : null,
          description: item.description && description is String
              ? cleanAutoDescription(description)
              : null,
        );
        if (answer.name != null || answer.description != null) {
          answers[item.id] = answer;
        }
      }
      return answers;
    } catch (e) {
      debugPrint('VOCAB: autofill failed: $e');
      return null;
    }
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'x-app-secret': VocabApiConfig.appSecret,
      };

  static Iterable<Map<String, String>> _words(List<WordPair> words) => [
        for (final w in words)
          if (w.word.trim().isNotEmpty)
            {
              'word': w.word.trim(),
              if (w.translation.trim().isNotEmpty)
                'translation': w.translation.trim(),
            },
      ];

  Future<String?> _ask(String path, String key, String? Function(String) clean,
      List<WordPair> words) async {
    final sent = _words(words).take(maxWords).toList();
    if (sent.isEmpty) return null;
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode({'words': sent, 'model': model}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('VOCAB: $path: status ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final answer = decoded is Map<String, dynamic> ? decoded[key] : null;
      return answer is String ? clean(answer) : null;
    } catch (e) {
      debugPrint('VOCAB: $path failed: $e');
      return null;
    }
  }
}
