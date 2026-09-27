import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/word_pair.dart';
import '../providers.dart' show WordDetailMode;

class SessionPublishException implements Exception {
  final String message;
  SessionPublishException(this.message);

  @override
  String toString() => message;
}

/// What `POST /sessions` answers: the id is the only credential the page has,
/// the url is what gets handed to the person across the table.
class PublishedSession {
  final String id;
  final String url;
  final DateTime? expiresAt;

  PublishedSession({required this.id, required this.url, this.expiresAt});
}

/// Publishes the current word list to the Worker as a public, read-only page
/// (task-05). Sits beside [VocabPhotoService] and reuses the same base URL and
/// shared secret; the file share stays the guaranteed return path, this is
/// the link next to it.
class SessionPublishService {
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;

  SessionPublishService({http.Client? client})
      : _client = client ?? http.Client();

  /// Blank pairs — the trailing empty row the input screen always keeps — are
  /// dropped here so they can never reach the page. Throws
  /// [SessionPublishException] when nothing is left to publish.
  ///
  /// [detail] is the learner's word detail mode at publishing time; the page
  /// and its AnkiDroid download show the columns it shows (definition-mode,
  /// ADR-0004). A field the mode hides is sent empty; definitions are sent
  /// only when the mode shows them.
  Future<PublishedSession> publish(
    List<WordPair> pairs, {
    WordDetailMode detail = WordDetailMode.translation,
  }) async {
    if (VocabApiConfig.appSecret.isEmpty) {
      throw SessionPublishException(
        'Vocab API secret is not configured. Fill in lib/config/vocab_api_config.dart.',
      );
    }

    final showTranslation = detail != WordDetailMode.definition;
    final showDefinition = detail != WordDetailMode.translation;
    final entries = [
      for (final pair in pairs)
        if (!pair.isEmpty)
          {
            'word': pair.word.trim(),
            'translation': showTranslation ? pair.translation.trim() : '',
            if (showDefinition) 'definition': pair.definition.trim(),
          },
    ];
    if (entries.isEmpty) {
      throw SessionPublishException('There are no words to publish');
    }

    final uri = Uri.parse('${VocabApiConfig.baseUrl}/sessions');
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'detail': detail.name, 'entries': entries}),
          )
          // A stalled connection must not leave the screen behind a spinner
          // forever (AC-16): the person is waiting to hand over a link.
          .timeout(_timeout);
    } on TimeoutException {
      throw SessionPublishException('The request timed out, please try again');
    } catch (e) {
      throw SessionPublishException('Network error: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw SessionPublishException(
        'Unexpected response (status ${response.statusCode})',
      );
    }

    if (response.statusCode != 200) {
      final error = decoded['error'] as String? ?? 'Request failed';
      throw SessionPublishException(error);
    }

    final id = decoded['id'] as String?;
    final url = decoded['url'] as String?;
    if (id == null || url == null) {
      throw SessionPublishException('Unexpected response: no link returned');
    }
    final expiresAt = decoded['expiresAt'] as String?;

    return PublishedSession(
      id: id,
      url: url,
      expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt) : null,
    );
  }
}
