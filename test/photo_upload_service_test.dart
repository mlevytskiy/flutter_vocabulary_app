import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/photo_upload_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_publish_service.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';

/// good-looking-web T18: declared photos upload in the background, retried
/// with back-off, never blocking the caller (ADR-0006, spec AC-37).
void main() {
  late Directory tmp;
  late SourcePhotoStore store;
  late List<Duration> sleeps;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('photo_upload_test');
    store = SourcePhotoStore(directory: tmp.path);
    sleeps = [];
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<SessionSource> kept(List<int> bytes) async =>
      (await store.keep(Uint8List.fromList(bytes)))!;

  PhotoUploadService uploader(http.Client client) => PhotoUploadService(
        client: client,
        store: store,
        sleep: (d) async => sleeps.add(d),
      );

  http.Response ok(http.Request r) => http.Response(
      jsonEncode({'sourceId': r.url.pathSegments.last}), 200,
      headers: {'content-type': 'application/json'});

  test('uploads the kept bytes to the declared id with the shared secret',
      () async {
    final photo = await kept([1, 2, 3]);
    final requests = <http.Request>[];
    final service = uploader(MockClient((r) async {
      requests.add(r);
      return ok(r);
    }));

    service.enqueue('sess-1', [photo]);
    await service.idle;

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/sessions/sess-1/sources/${photo.id}');
    expect(request.headers['content-type'], 'image/jpeg');
    expect(request.headers['x-app-secret'], isNotEmpty);
    expect(request.bodyBytes, [1, 2, 3]);
    expect(service.uploaded, {photo.id});
  });

  // AC-37
  test('two failures then success: uploaded, after growing pauses', () async {
    final photo = await kept([7]);
    var calls = 0;
    final service = uploader(MockClient((r) async {
      calls++;
      if (calls == 1) return http.Response('busy', 503);
      if (calls == 2) throw http.ClientException('connection reset');
      return ok(r);
    }));

    service.enqueue('sess-1', [photo]);
    await service.idle;

    expect(calls, 3);
    expect(service.uploaded, {photo.id});
    expect(sleeps, hasLength(2));
    expect(sleeps[1], greaterThan(sleeps[0]));
  });

  // AC-37
  test('publish returns before any upload completes', () async {
    final photo = await kept([9]);
    final gate = Completer<void>();
    final events = <String>[];
    final client = MockClient((r) async {
      if (r.url.path == '/sessions') {
        return http.Response(
            jsonEncode({
              'id': 'sess-1',
              'url': 'https://example.test/s/sess-1',
              'editToken': 'tok',
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      await gate.future;
      events.add('uploaded');
      return ok(r);
    });
    final publisher = SessionPublishService(client: client);
    final service = uploader(client);

    final published = await publisher.publish(
      [WordPair(word: 'tea', translation: 'чай', sourceId: photo.id)],
      sources: [photo],
    );
    service.enqueue(published.id, published.declaredSources);
    events.add('dialog');

    expect(service.uploaded, isEmpty);
    gate.complete();
    await service.idle;
    expect(events, ['dialog', 'uploaded']);
    expect(service.uploaded, {photo.id});
  });

  test('gives up after the last attempt and never throws', () async {
    final photo = await kept([1]);
    var calls = 0;
    final service = uploader(MockClient((r) async {
      calls++;
      return http.Response('down', 502);
    }));

    service.enqueue('sess-1', [photo]);
    await service.idle;

    expect(calls, PhotoUploadService.maxAttempts);
    expect(service.uploaded, isEmpty);
  });

  test('a refusal (undeclared id) is not retried', () async {
    final photo = await kept([1]);
    var calls = 0;
    final service = uploader(MockClient((r) async {
      calls++;
      return http.Response('{"error":"no such source"}', 404);
    }));

    service.enqueue('sess-1', [photo]);
    await service.idle;

    expect(calls, 1);
    expect(sleeps, isEmpty);
  });

  test('a photo whose file is gone is skipped without a request', () async {
    final photo = await kept([1]);
    await store.delete(photo);
    var calls = 0;
    final service = uploader(MockClient((r) async {
      calls++;
      return ok(r);
    }));

    service.enqueue('sess-1', [photo]);
    await service.idle;

    expect(calls, 0);
  });

  test('enqueueing the same photo twice uploads it once', () async {
    final photo = await kept([1]);
    var calls = 0;
    final service = uploader(MockClient((r) async {
      calls++;
      return ok(r);
    }));

    service.enqueue('sess-1', [photo]);
    service.enqueue('sess-1', [photo]);
    await service.idle;

    expect(calls, 1);
  });
}
