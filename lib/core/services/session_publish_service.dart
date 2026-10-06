import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/session_source.dart';
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

  /// Lets the next publish of this session overwrite the same link
  /// (ADR-0008). Null from a Worker that predates republishing.
  final String? editToken;

  /// The sources the request declared (photos and sets), in pager order:
  /// the photos' bytes still have to be uploaded, a set needs nothing more
  /// (ADR-0006).
  final List<SessionSource> declaredSources;

  PublishedSession({
    required this.id,
    required this.url,
    this.expiresAt,
    this.editToken,
    this.declaredSources = const [],
  });
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
  /// ADR-0004). Every stored translation and definition is sent whatever the
  /// mode, and the page decides which columns to show (AC-27).
  ///
  /// [sources] are the session's photos and sets when "include sources" is
  /// on; empty means off, and then neither `sources` nor any `sourceId` is
  /// sent (AC-24). Only sources with a linked row are declared, all of them,
  /// by taken time; each goes with its kind, and a set with its name and link
  /// (ADR-0006). [publishedId] and [editToken] ask the Worker to
  /// overwrite the earlier link (ADR-0008).
  Future<PublishedSession> publish(
    List<WordPair> pairs, {
    WordDetailMode detail = WordDetailMode.translation,
    List<SessionSource> sources = const [],
    String? publishedId,
    String? editToken,
  }) async {
    if (VocabApiConfig.appSecret.isEmpty) {
      throw SessionPublishException(
        'Vocab API secret is not configured. Fill in lib/config/vocab_api_config.dart.',
      );
    }

    final kept = [
      for (final pair in pairs)
        if (!pair.isEmpty) pair
    ];
    final linkedIds = {for (final pair in kept) pair.sourceId};
    final linked = [
      for (final source in sources)
        if (linkedIds.contains(source.id)) source,
    ];
    // List.sort is not stable: the position breaks ties between equal times.
    final declared = [
      for (final (_, source) in ([...linked.indexed]..sort((a, b) {
          final byTime = a.$2.takenAt.compareTo(b.$2.takenAt);
          return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
        })))
        source,
    ];
    final declaredIds = {for (final source in declared) source.id};

    final entries = [
      for (final pair in kept)
        {
          'word': pair.word.trim(),
          'translation': pair.translation.trim(),
          if (pair.definition.trim().isNotEmpty)
            'definition': pair.definition.trim(),
          if (declaredIds.contains(pair.sourceId)) 'sourceId': pair.sourceId,
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
            body: jsonEncode({
              'detail': detail.name,
              'entries': entries,
              if (declared.isNotEmpty)
                'sources': [
                  for (var i = 0; i < declared.length; i++)
                    {
                      'id': declared[i].id,
                      'order': i,
                      'kind': declared[i].kind.name,
                      if (declared[i].kind == SourceKind.set) ...{
                        'name': declared[i].name,
                        'url': declared[i].url,
                      },
                    },
                ],
              if (publishedId != null && editToken != null) ...{
                'publishedId': publishedId,
                'editToken': editToken,
              },
            }),
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
      decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
      editToken: decoded['editToken'] as String?,
      declaredSources: declared,
    );
  }
}
