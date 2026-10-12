import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';

/// A 1×1 PNG.
final kPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// Returns the bytes given per source id; an id it does not know reads as
/// missing (null), as `SourcePhotoStore.read` does for a gone file.
class MapSourcePhotoStore extends SourcePhotoStore {
  MapSourcePhotoStore(this.bytes);
  final Map<String, Uint8List> bytes;
  final reads = <String>[];

  @override
  Future<Uint8List?> read(SessionSource photo) async {
    reads.add(photo.id);
    return bytes[photo.id];
  }
}

SessionSource photoSource(String id) => SessionSource()
  ..id = id
  ..fileName = '$id.jpg';

/// side-bar-for-main-screen T5: a photo decoded at preview size, and the
/// "not available" placeholder for a missing or broken file (spec AC-09).
void main() {
  Future<MapSourcePhotoStore> pumpPreviews(
    WidgetTester tester,
    Map<String, Uint8List> bytes,
    List<String> ids, {
    double width = 48,
  }) async {
    final store = MapSourcePhotoStore(bytes);
    await tester.pumpWidget(ProviderScope(
      overrides: [sourcePhotoStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        home: Column(children: [
          for (final id in ids)
            SizedBox(
              key: ValueKey(id),
              width: width,
              height: width,
              child: PhotoPreview(source: photoSource(id), width: width),
            ),
        ]),
      ),
    ));
    // Reading and decoding are real async work: give it a few real turns.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    return store;
  }

  Finder inside(String id, Finder f) => find.descendant(of: find.byKey(ValueKey(id)), matching: f);

  testWidgets('the file is read only after the first frame', (tester) async {
    final store = MapSourcePhotoStore({'p1': kPng});
    await tester.pumpWidget(ProviderScope(
      overrides: [sourcePhotoStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: PhotoPreview(source: photoSource('p1'), width: 48)),
    ));
    // The first frame is drawn without the photo; the read starts after it.
    expect(store.reads, ['p1']);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(PhotoNotAvailable), findsNothing);
  });

  testWidgets('a readable photo decodes at width × device pixel ratio', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPreviews(tester, {'p1': kPng}, ['p1'], width: 48);

    final image = tester.widget<Image>(inside('p1', find.byType(Image)));
    expect((image.image as ResizeImage).width, 144);
    expect(inside('p1', find.byType(PhotoNotAvailable)), findsNothing);
  });

  testWidgets('the decode width follows another device pixel ratio', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPreviews(tester, {'p1': kPng}, ['p1'], width: 60);

    final image = tester.widget<Image>(inside('p1', find.byType(Image)));
    expect((image.image as ResizeImage).width, 120);
  });

  testWidgets('a missing file and a broken file show the placeholder; the others still show',
      (tester) async {
    await pumpPreviews(
      tester,
      {'ok': kPng, 'broken': Uint8List.fromList([1, 2, 3, 4])},
      ['ok', 'gone', 'broken'],
    );

    expect(inside('gone', find.byType(PhotoNotAvailable)), findsOneWidget);
    expect(inside('broken', find.byType(PhotoNotAvailable)), findsOneWidget);
    expect(inside('ok', find.byType(PhotoNotAvailable)), findsNothing);
    expect(inside('ok', find.byType(Image)), findsOneWidget);
    expect(find.bySemanticsLabel('Photo not available'), findsNWidgets(2));
  });

  testWidgets('a look can give its own placeholder', (tester) async {
    final store = MapSourcePhotoStore({});
    await tester.pumpWidget(ProviderScope(
      overrides: [sourcePhotoStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        home: PhotoPreview(
          source: photoSource('gone'),
          width: 48,
          placeholder: (_) => const Text('custom placeholder'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('custom placeholder'), findsOneWidget);
  });
}
