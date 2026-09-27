import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/source_photo.dart';
import 'source_photo_store.dart';

/// Uploads the bytes of the photos a publish declared, each to its declared
/// id (`POST /sessions/<id>/sources/<sourceId>`, ADR-0006), in the background.
///
/// [enqueue] returns at once: the link dialog never waits for a photo (AC-37).
/// Each photo is retried with growing pauses while the app runs; one that
/// never arrives stays a placeholder on the page with its rows still linked,
/// so failures are logged, never thrown or shown.
class PhotoUploadService {
  static const _timeout = Duration(seconds: 60);

  /// Attempts per photo, and the pause before the second one; each later
  /// pause doubles (2, 4, 8, 16 s).
  static const maxAttempts = 5;
  static const firstPause = Duration(seconds: 2);

  final http.Client _client;
  final SourcePhotoStore _store;
  final Future<void> Function(Duration) _sleep;

  /// `<publishedId>/<photoId>` of every upload still running.
  final Map<String, Future<void>> _running = {};

  /// Ids of the photos that reached the Worker.
  final Set<String> uploaded = {};

  PhotoUploadService({
    http.Client? client,
    required SourcePhotoStore store,
    Future<void> Function(Duration)? sleep,
  })  : _client = client ?? http.Client(),
        _store = store,
        _sleep = sleep ?? Future<void>.delayed;

  /// Starts uploading [photos] to the session published as [publishedId]. A
  /// photo already uploading to that session is not started twice.
  void enqueue(String publishedId, List<SourcePhoto> photos) {
    for (final photo in photos) {
      final key = '$publishedId/${photo.id}';
      if (_running.containsKey(key)) continue;
      // A block, not `=> _running.remove(key)`: that returns this very future,
      // and whenComplete would wait on itself.
      _running[key] = _upload(publishedId, photo).whenComplete(() {
        _running.remove(key);
      });
    }
  }

  /// Completes once every upload started so far has finished or given up.
  Future<void> get idle async {
    while (_running.isNotEmpty) {
      await Future.wait(_running.values.toList());
    }
  }

  Future<void> _upload(String publishedId, SourcePhoto photo) async {
    try {
      final bytes = await _store.read(photo);
      if (bytes == null) {
        debugPrint('VOCAB: source photo ${photo.id} is gone, not uploaded');
        return;
      }
      final uri = Uri.parse(
          '${VocabApiConfig.baseUrl}/sessions/$publishedId/sources/${photo.id}');
      var pause = firstPause;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (attempt > 1) {
          await _sleep(pause);
          pause *= 2;
        }
        final status = await _post(uri, bytes);
        if (status == 200) {
          uploaded.add(photo.id);
          return;
        }
        // Any other 4xx is a refusal (undeclared id, too large, bad type):
        // sending the same bytes again cannot change the answer.
        if (status != null && status >= 400 && status < 500 && status != 429) {
          debugPrint('VOCAB: upload of ${photo.id} refused ($status)');
          return;
        }
      }
      debugPrint('VOCAB: upload of ${photo.id} gave up after $maxAttempts tries');
    } catch (e) {
      debugPrint('VOCAB: upload of ${photo.id} failed: $e');
    }
  }

  /// The response status, or null when the request did not get an answer.
  Future<int?> _post(Uri uri, Uint8List bytes) async {
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'image/jpeg',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: bytes,
          )
          .timeout(_timeout);
      return response.statusCode;
    } catch (e) {
      debugPrint('VOCAB: upload request failed: $e');
      return null;
    }
  }
}
