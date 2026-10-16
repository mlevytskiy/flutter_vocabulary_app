import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/film_dialogue.dart';
import '../models/session_source.dart';
import '../models/word_pair.dart';
import '../providers.dart' show WordDetailMode;

class CollectionPublishException implements Exception {
  final String message;
  CollectionPublishException(this.message);

  @override
  String toString() => message;
}

/// What `POST /sessions` answers: the id is the only credential the page has,
/// the url is what gets handed to the person across the table.
class PublishedCollection {
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

  /// The film dialogues the request carried, in pager order; those with a
  /// picture declared still have it to upload
  /// (get-words-from-subtitles-improvment ADR-0005).
  final List<FilmDialogue> declaredDialogues;

  PublishedCollection({
    required this.id,
    required this.url,
    this.expiresAt,
    this.editToken,
    this.declaredSources = const [],
    this.declaredDialogues = const [],
  });
}

/// The source kinds the Worker accepts in `sources` (photo, set). The Worker
/// refuses the whole publish for any other kind, so a film's subtitles source
/// is never declared and its rows go without a `sourceId`, as before
/// (side-panel-sources, spec AC-22).
const publishedSourceKinds = {SourceKind.photo, SourceKind.set};

/// Publishes the current word list to the Worker as a public, read-only page
/// (task-05). Sits beside [VocabPhotoService] and reuses the same base URL and
/// shared secret; the file share stays the guaranteed return path, this is
/// the link next to it.
class CollectionPublishService {
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;

  CollectionPublishService({http.Client? client})
      : _client = client ?? http.Client();

  /// Blank pairs — the trailing empty row the input screen always keeps — are
  /// dropped here so they can never reach the page. Throws
  /// [CollectionPublishException] when nothing is left to publish.
  ///
  /// [detail] is the learner's word detail mode at publishing time; the page
  /// and its AnkiDroid download show the columns it shows (definition-mode,
  /// ADR-0004). Every stored translation and definition is sent whatever the
  /// mode, and the page decides which columns to show (AC-27).
  ///
  /// [sources] are the session's sets, always, and its photos when "Include
  /// photos" is on; empty means none, and then neither `sources` nor any
  /// `sourceId` is sent (AC-24). Only sources with a linked row are declared, all of them,
  /// by taken time; each goes with its kind, and a set with its name and link
  /// (ADR-0006). A kind outside [publishedSourceKinds] is left out (AC-22). [publishedId] and [editToken] ask the Worker to
  /// overwrite the earlier link (ADR-0008).
  ///
  /// [dialogues] are the session's film dialogues: each visible one with a
  /// word still published goes with its lines, the positions of its rows in
  /// `entries`, its import id and, when drawn, its scene picture declared
  /// like a photo (get-words-from-subtitles-improvment ADR-0005). None sends
  /// no `dialogues` key.
  ///
  /// [title] is the collection's name, sent on a create and a republish so
  /// the shared page shows it (collections-screen AC-29, ADR-0008); null
  /// sends no `title`. Dialogue and picture deliveries never send it.
  Future<PublishedCollection> publish(
    List<WordPair> pairs, {
    WordDetailMode detail = WordDetailMode.translation,
    List<SessionSource> sources = const [],
    String? publishedId,
    String? editToken,
    List<FilmDialogue> dialogues = const [],
    String? title,
  }) async {
    if (VocabApiConfig.appSecret.isEmpty) {
      throw CollectionPublishException(
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
        if (publishedSourceKinds.contains(source.kind) &&
            linkedIds.contains(source.id))
          source,
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
      throw CollectionPublishException('There are no words to publish');
    }

    final position = <String, int>{
      for (final (i, pair) in kept.indexed)
        if (pair.rowId.isNotEmpty) pair.rowId: i,
    };
    final sentDialogues = <FilmDialogue>[];
    final dialoguesJson = <Map<String, dynamic>>[];
    for (final d in dialogues) {
      if (d.hidden) continue;
      final at = [
        for (final id in d.wordRowIds)
          if (position[id] case final i?) i,
      ];
      if (at.isEmpty) continue;
      sentDialogues.add(d);
      dialoguesJson.add({
        'id': d.id,
        'lines': d.lines,
        'entries': at,
        if (d.importId != null) 'importId': d.importId,
        if (d.scenePictureRunId != null) 'picture': {'mediaType': 'image/jpeg'},
      });
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
              if (title != null) 'title': title,
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
              if (dialoguesJson.isNotEmpty) 'dialogues': dialoguesJson,
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
      throw CollectionPublishException(
          'The request timed out, please try again');
    } catch (e) {
      throw CollectionPublishException('Network error: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw CollectionPublishException(
        'Unexpected response (status ${response.statusCode})',
      );
    }

    if (response.statusCode != 200) {
      final error = decoded['error'] as String? ?? 'Request failed';
      throw CollectionPublishException(error);
    }

    final id = decoded['id'] as String?;
    final url = decoded['url'] as String?;
    if (id == null || url == null) {
      throw CollectionPublishException('Unexpected response: no link returned');
    }
    final expiresAt = decoded['expiresAt'] as String?;

    return PublishedCollection(
      id: id,
      url: url,
      expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt) : null,
      editToken: decoded['editToken'] as String?,
      declaredSources: declared,
      declaredDialogues: sentDialogues,
    );
  }
}
