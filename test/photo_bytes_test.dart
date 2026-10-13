import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_bytes.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';

import 'photo_panel_test_host.dart';
import 'photo_preview_test.dart' show MapSourcePhotoStore, kPng, photoSource;

/// The photo panel opens without reading and decoding its photos again: the
/// bytes are read once and kept, the previews are decoded ahead while the tab
/// sits there, and a kept photo shows in its preview's first frame.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SourcePhotoBytes', () {
    test('reads a source once, even while a read is under way', () async {
      final store = MapSourcePhotoStore({'p1': kPng});
      final bytes = SourcePhotoBytes(store);
      final first = bytes.read(photoSource('p1'));
      final again = bytes.read(photoSource('p1'));
      expect(identical(await first, await again), isTrue);
      expect(identical(await bytes.read(photoSource('p1')), await first), isTrue);
      expect(store.reads, ['p1']);
      expect(bytes.peek(photoSource('p1')), same(await first));
    });

    test('a missing file is not kept: it is read again next time', () async {
      final store = MapSourcePhotoStore({});
      final bytes = SourcePhotoBytes(store);
      expect(await bytes.read(photoSource('gone')), isNull);
      expect(bytes.peek(photoSource('gone')), isNull);
      await bytes.read(photoSource('gone'));
      expect(store.reads, ['gone', 'gone']);
    });

    test('keeps at most ${SourcePhotoBytes.keep}, dropping the oldest', () async {
      final store = MapSourcePhotoStore(
          {for (var i = 0; i <= SourcePhotoBytes.keep; i++) 'p$i': kPng});
      final bytes = SourcePhotoBytes(store);
      for (var i = 0; i <= SourcePhotoBytes.keep; i++) {
        await bytes.read(photoSource('p$i'));
      }
      expect(bytes.peek(photoSource('p0')), isNull);
      expect(bytes.peek(photoSource('p${SourcePhotoBytes.keep}')), isNotNull);
    });
  });

  testWidgets('a photo read before shows in the first frame, with no new read', (tester) async {
    final store = MapSourcePhotoStore({'p1': kPng});
    final container = ProviderContainer(
        overrides: [sourcePhotoStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(sourcePhotoBytesProvider).read(photoSource('p1'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PhotoPreview(source: photoSource('p1'), width: 48)),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(store.reads, ['p1'], reason: 'no second read');
  });

  testWidgets('the panel reads its photos once and decodes them ahead, while closed',
      (tester) async {
    final store = MapSourcePhotoStore({'p0': kPng, 'p1': kPng, 'p2': kPng});
    final host = PanelHost(store: store);
    await host.pump(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(store.reads.toSet(), {'p0', 'p1', 'p2'}, reason: 'read ahead, closed');
    final readsBefore = store.reads.length;

    // Opening: every small photo is an image from its first frame.
    await tester.tap(tabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    for (final id in ['p0', 'p1', 'p2']) {
      expect(find.descendant(of: smallPhoto(id), matching: find.byType(Image)), findsOneWidget,
          reason: '$id shows at once');
    }
    await tester.pumpAndSettle();
    expect(store.reads.length, readsBefore, reason: 'no file read again');
    expect(find.byKey(PhotoPanel.panelKey), findsOneWidget);
  });
}
