import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config/vocab_api_config.dart';
import '../../features/word_input/word_input_notifier.dart';
import '../models/film_dialogue.dart';
import '../models/session.dart';
import '../providers.dart';

part 'dialogue_push.g.dart';

/// What became of one delivery to the shared link.
enum PushOutcome {
  /// The Worker has it (or already had it: a repeat adds nothing).
  delivered,

  /// The link is gone, the token was replaced, or the Worker refused the
  /// content: sending it again cannot help (sad §11).
  dropped,

  /// No answer, a busy or failing Worker: try again later.
  retry,
}

/// The app's two calls that add to a published session without a republish
/// (get-words-from-subtitles-improvment ADR-0005): an import's rows and
/// dialogues, and a dialogue's scene picture. Both carry the edit token.
class DialoguePushService {
  static const _timeout = Duration(seconds: 60);

  final http.Client _client;

  DialoguePushService({http.Client? client}) : _client = client ?? http.Client();

  /// POST /sessions/<id>/dialogues with [body] (see [appendBody]).
  Future<PushOutcome> append(
          String publishedId, String editToken, Map<String, dynamic> body) =>
      _post(
        Uri.parse('${VocabApiConfig.baseUrl}/sessions/$publishedId/dialogues'),
        editToken,
        'application/json; charset=utf-8',
        utf8.encode(jsonEncode(body)),
      );

  /// POST /sessions/<id>/dialogues/<dialogueId>/picture with the JPEG bytes.
  Future<PushOutcome> uploadPicture(String publishedId, String editToken,
          String dialogueId, Uint8List bytes) =>
      _post(
        Uri.parse(
            '${VocabApiConfig.baseUrl}/sessions/$publishedId/dialogues/$dialogueId/picture'),
        editToken,
        'image/jpeg',
        bytes,
      );

  Future<PushOutcome> _post(
      Uri uri, String editToken, String contentType, List<int> body) async {
    final int status;
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'content-type': contentType,
              'x-app-secret': VocabApiConfig.appSecret,
              'x-edit-token': editToken,
            },
            body: body,
          )
          .timeout(_timeout);
      status = response.statusCode;
    } catch (e) {
      debugPrint('VOCAB: dialogue delivery failed: $e');
      return PushOutcome.retry;
    }
    if (status == 200) return PushOutcome.delivered;
    if (status == 429 || status >= 500) return PushOutcome.retry;
    debugPrint('VOCAB: dialogue delivery refused ($status), dropped');
    return PushOutcome.dropped;
  }
}

/// The pause before the first retry; each later one doubles, up to 64 times
/// it. Tests make it short.
final dialoguePushPauseProvider =
    Provider<Duration>((ref) => const Duration(seconds: 2));

/// The append body of the import [importId] of [session]: the import's rows
/// that still exist, in session order, and its dialogues that still have
/// words, each naming its rows by position. Null when none of its rows is
/// left, so there is nothing to send (ADR-0005).
Map<String, dynamic>? appendBody(Session session, String importId) {
  final ofImport = [
    for (final d in session.dialogues)
      if (d.importId == importId) d,
  ];
  final importRows = {for (final d in ofImport) ...d.importRowIds};
  final rows = [
    for (final w in session.words)
      if (!w.isEmpty && importRows.contains(w.rowId)) w,
  ];
  if (rows.isEmpty) return null;
  final position = {for (final (i, w) in rows.indexed) w.rowId: i};
  return {
    'importId': importId,
    'entries': [
      for (final w in rows)
        {
          'word': w.word.trim(),
          'translation': w.translation.trim(),
          if (w.definition.trim().isNotEmpty) 'definition': w.definition.trim(),
        },
    ],
    'dialogues': [
      for (final d in ofImport)
        if (!d.hidden)
          if ([
            for (final id in d.wordRowIds)
              if (position[id] case final i?) i,
          ]
              case final at when at.isNotEmpty)
            {
              'id': d.id,
              'lines': d.lines,
              'entries': at,
              if (d.scenePictureRunId != null)
                'picture': {'mediaType': 'image/jpeg'},
            },
    ],
  };
}

/// The dialogues once the import [importId] reached the link, or was dropped:
/// a hidden one goes, the others are delivered. Returns copies.
List<FilmDialogue> importDone(List<FilmDialogue> dialogues, String importId) => [
      for (final d in dialogues)
        if (d.importId != importId)
          d
        else if (!d.hidden)
          d.copy()..pushState = PushState.delivered,
    ];

/// The dialogues once [dialogueId]'s picture reached the link, or was
/// dropped. Returns copies.
List<FilmDialogue> pictureDone(List<FilmDialogue> dialogues, String dialogueId) => [
      for (final d in dialogues)
        d.id == dialogueId ? (d.copy()..picturePushState = PushState.delivered) : d,
    ];

bool _isPending(Session s) =>
    s.publishedId != null &&
    s.editToken != null &&
    s.dialogues.any((d) =>
        d.pushState == PushState.pending ||
        (d.pushState == PushState.delivered &&
            d.picturePushState == PushState.pending));

/// Delivers what the sessions with a shared link still owe it
/// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
/// and dialogues, then each pending scene picture whose dialogue the page
/// has. Runs once on app start (read in `app.dart`), whenever the current
/// session gains something to deliver, and again with growing pauses while
/// anything failed. The state lives on the `FilmDialogue`s, so closing the
/// app loses nothing. Never throws.
@Riverpod(keepAlive: true)
class DialoguePush extends _$DialoguePush {
  bool _disposed = false;
  bool _running = false;
  bool _again = false;
  Timer? _timer;
  Duration? _pause;

  /// The run made when the outbox comes up (app start).
  @visibleForTesting
  Future<void> startup = Future.value();

  @override
  void build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    ref.listen(wordInputNotifierProvider, (_, next) {
      final session = next.valueOrNull;
      // A retry already waiting picks this up too.
      if (session != null && _isPending(session) && _timer == null) {
        unawaited(run());
      }
    });
    startup = Future(run);
  }

  /// One pass over every session with a link. A call while one is going
  /// makes that one look again.
  Future<void> run() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    var retry = false;
    try {
      do {
        _again = false;
        retry = await _pass();
      } while (_again && !_disposed);
    } catch (e) {
      debugPrint('VOCAB: delivering dialogues failed: $e');
      retry = true;
    } finally {
      _running = false;
    }
    _schedule(retry);
  }

  void _schedule(bool retry) {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !retry) {
      _pause = null;
      return;
    }
    final base = ref.read(dialoguePushPauseProvider);
    final next = _pause == null ? base : _pause! * 2;
    _pause = next > base * 64 ? base * 64 : next;
    _timer = Timer(_pause!, () {
      _timer = null;
      unawaited(run());
    });
  }

  /// Returns true when something should be tried again.
  Future<bool> _pass() async {
    final store = await ref.read(sessionStoreProvider.future);
    final current = await ref.read(wordInputNotifierProvider.future);
    final ids = <String>[
      current.sessionId,
      for (final s in await store.nonEmpty())
        if (s.sessionId != current.sessionId) s.sessionId,
    ];
    var retry = false;
    for (final id in ids) {
      if (_disposed) return false;
      final session = await _read(id);
      if (session == null || !_isPending(session)) continue;
      if (await _deliver(session)) retry = true;
    }
    return retry;
  }

  Future<bool> _deliver(Session first) async {
    final service = ref.read(dialoguePushServiceProvider);
    final publishedId = first.publishedId!;
    final editToken = first.editToken!;
    var retry = false;

    final imports = <String>{
      for (final d in first.dialogues)
        if (d.pushState == PushState.pending && d.importId != null) d.importId!,
    };
    for (final importId in imports) {
      final session = await _read(first.sessionId);
      if (session == null || _disposed) return false;
      final body = appendBody(session, importId);
      final outcome = body == null
          ? PushOutcome.delivered
          : await service.append(publishedId, editToken, body);
      if (outcome == PushOutcome.retry) {
        retry = true;
        continue;
      }
      await _change(first.sessionId, (ds) => importDone(ds, importId));
    }

    final session = await _read(first.sessionId);
    if (session == null) return retry;
    for (final d in session.dialogues) {
      if (_disposed) return false;
      if (d.pushState != PushState.delivered ||
          d.picturePushState != PushState.pending ||
          d.scenePictureRunId == null) {
        continue;
      }
      final bytes = await _pictureBytes(d.scenePictureRunId!);
      final outcome = bytes == null
          ? PushOutcome.dropped
          : await service.uploadPicture(publishedId, editToken, d.id, bytes);
      if (outcome == PushOutcome.retry) {
        retry = true;
        continue;
      }
      await _change(first.sessionId, (ds) => pictureDone(ds, d.id));
    }
    return retry;
  }

  Future<Uint8List?> _pictureBytes(String runId) async {
    final run = await (await ref.read(storyRunStoreProvider.future)).byId(runId);
    final picture = run?.steps
        .where((s) =>
            s.role == 'picture' && s.outcome == 'done' && s.picturePath != null)
        .lastOrNull;
    if (picture == null) return null;
    return ref.read(storyPictureStoreProvider).read(runId, picture.attempt);
  }

  /// The current session's live object, or a History session from the store.
  Future<Session?> _read(String sessionId) async {
    final current = await ref.read(wordInputNotifierProvider.future);
    if (current.sessionId == sessionId) return current;
    return (await ref.read(sessionStoreProvider.future)).byId(sessionId);
  }

  Future<void> _change(String sessionId,
      List<FilmDialogue> Function(List<FilmDialogue>) change) async {
    final current = await ref.read(wordInputNotifierProvider.future);
    if (current.sessionId == sessionId) {
      await ref.read(wordInputNotifierProvider.notifier).updateDialogues(change);
      return;
    }
    final store = await ref.read(sessionStoreProvider.future);
    final session = await store.byId(sessionId);
    if (session == null) return;
    session.dialogues = change(session.dialogues);
    await store.put(session);
  }
}
