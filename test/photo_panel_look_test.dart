import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_b.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_c.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/looks.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/photo_panel_look.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photos_with_words.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'photo_panel_test_host.dart';
import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// A look whose tab is taller than Android's 200 dp per-edge limit.
class _TallLook extends LookA {
  const _TallLook();
  @override
  double tabHeight(int count) => 250;
}

List<PhotoWithWords> photos(int n) => [
      for (var i = 0; i < n; i++)
        (
          source: SessionSource()
            ..id = 'p$i'
            ..fileName = 'p$i.jpg',
          rows: [i],
        ),
    ];

/// side-bar-for-main-screen T6: the look interface and look A (ADR-0003,
/// spec AC-19; ADR-0002 for the 200 dp limit).
void main() {
  group('registry', () {
    test('variant a is look A, b is look B, c is look C', () {
      expect(lookFor(PhotoPanelVariant.a), isA<LookA>());
      expect(lookFor(PhotoPanelVariant.b), isA<LookB>());
      expect(lookFor(PhotoPanelVariant.c), isA<LookC>());
    });

    test('look C chooses differently from look B on hiding the tab', () {
      expect(lookFor(PhotoPanelVariant.c).hidesTabWhileScrolling,
          isNot(lookFor(PhotoPanelVariant.b).hidesTabWhileScrolling));
    });

    test('the looks differ where AC-19 allows: B hides the tab while scrolling, A does not', () {
      expect(lookFor(PhotoPanelVariant.a).hidesTabWhileScrolling, isFalse);
      expect(lookFor(PhotoPanelVariant.b).hidesTabWhileScrolling, isTrue);
      final hides = {for (final v in PhotoPanelVariant.values) lookFor(v).hidesTabWhileScrolling};
      expect(hides, {true, false});
    });
    test('every variant has a look', () {
      for (final v in PhotoPanelVariant.values) {
        expect(lookFor(v), isA<PhotoPanelLook>());
      }
    });
  });

  group('every registered look', () {
    for (final v in PhotoPanelVariant.values) {
      final look = lookFor(v);
      test('$v: the tab is at most 200 dp tall for any photo count', () {
        for (final n in [1, 2, 3, 4, 50]) {
          expect(tabSizeFor(look, n).height, lessThanOrEqualTo(PhotoPanelLook.maxTabHeight));
        }
      });
      testWidgets('$v: tab, half-open, full-open and browsing draw without errors',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final host = PanelHost(photos: fakePhotos(4), look: look);
        await host.pump(tester);
        expect(find.byType(PhotoPreview).evaluate().length, lessThanOrEqualTo(3),
            reason: 'at most three mini previews');
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        expect(host.controller.stop, PanelStop.halfOpen);
        await tester.tap(smallPhoto('p1'));
        await tester.pump();
        await tester.tap(find.byKey(PhotoPanel.expandKey));
        await tester.pumpAndSettle();
        expect(host.controller.stop, PanelStop.fullOpen);
        expect(find.byKey(PhotoPanel.largePhotoKey('p1')), findsOneWidget);
        // Browse to another photo, the look's way; the selection stays.
        final browser = tester.getRect(find.byKey(PhotoPanel.largeBrowserKey));
        await tester.flingFrom(browser.center, const Offset(-300, -300), 2000);
        await tester.pumpAndSettle();
        expect(host.controller.selectedId, 'p1');
        expect(tester.takeException(), isNull);
      });

      testWidgets('$v: the row highlight is non-null', (tester) async {
        late Decoration highlight;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            highlight = look.rowHighlight(context);
            return const SizedBox();
          }),
        ));
        expect(highlight, isNotNull);
      });
    }
  });

  test('a tab taller than 200 dp fails the interface check', () {
    expect(() => tabSizeFor(const _TallLook(), 3), throwsA(isA<AssertionError>()));
  });

  testWidgets('look A draws at most three mini previews plus the count', (tester) async {
    const look = LookA();
    await tester.pumpWidget(ProviderScope(
      overrides: [sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({}))],
      child: MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: tabSizeFor(look, 5),
            child: Builder(
              builder: (context) => look.buildTab(
                context,
                photos: photos(5),
                preview: (p, width) => PhotoPreview(source: p.source, width: width),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(PhotoPreview), findsNWidgets(3));
    expect(find.text('5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('look A with one photo draws one preview and its count', (tester) async {
    const look = LookA();
    await tester.pumpWidget(ProviderScope(
      overrides: [sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({}))],
      child: MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: tabSizeFor(look, 1),
            child: Builder(
              builder: (context) => look.buildTab(
                context,
                photos: photos(1),
                preview: (p, width) => PhotoPreview(source: p.source, width: width),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(PhotoPreview), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
