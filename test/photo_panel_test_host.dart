import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/notes/notes_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/photo_panel_look.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photos_with_words.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// Shared host for the photo panel widget tests (side-bar-for-main-screen):
/// a Scaffold with an AppBar and a list of 50 rows of 60 px, with the panel
/// mounted over the list as the main screen mounts it.
List<PhotoWithWords> fakePhotos(int n, {int rowsEach = 1}) => [
      for (var i = 0; i < n; i++)
        (
          source: SessionSource()
            ..id = 'p$i'
            ..fileName = 'p$i.jpg'
            ..takenAt = DateTime(2026, 10, 13, 9, i),
          rows: [for (var r = 0; r < rowsEach; r++) i * rowsEach + r],
        ),
    ];

/// A Quizlet set with words, for the side-panel-sources tests.
SourceWithWords fakeSet(String id, {String name = 'Set', int at = 0, List<int> rows = const [40]}) => (
      source: SessionSource()
        ..id = id
        ..kind = SourceKind.set
        ..name = name
        ..url = 'https://quizlet.com/$id/x/'
        ..takenAt = DateTime(2026, 10, 13, 9, at),
      rows: rows,
    );

class PanelHost {
  PanelHost({
    List<PhotoWithWords>? photos,
    this.busy = false,
    this.hidden = false,
    this.bottomReserve = 80,
    this.look,
    this.rows = 50,
    MapSourcePhotoStore? store,
  })  : photos = ValueNotifier(photos ?? fakePhotos(3)),
        store = store ?? MapSourcePhotoStore({});

  final MapSourcePhotoStore store;

  final ValueNotifier<List<PhotoWithWords>> photos;
  final bool busy;
  final bool hidden;
  final double bottomReserve;
  final PhotoPanelLook? look;
  final int rows;
  final controller = PhotoPanelController();
  final scroll = ScrollController();
  final selections = <String?>[];
  final tappedRows = <int>[];
  final field = TextEditingController(text: 'half-typed');
  final fieldFocus = FocusNode();

  Widget build({Key? key}) => ProviderScope(
        key: key,
        overrides: [
          // The panel's sources (photos and sets); photosWithWords derives
          // from it.
          sourcesWithWordsProvider.overrideWith((ref) {
            void update() => ref.state = photos.value;
            photos.addListener(update);
            ref.onDispose(() => photos.removeListener(update));
            return photos.value;
          }),
          sourcePhotoStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Main')),
            body: Stack(
              children: [
                ListView.builder(
                  key: const Key('host-list'),
                  controller: scroll,
                  itemCount: rows,
                  itemBuilder: (context, i) => SizedBox(
                    height: 60,
                    child: i == 0
                        ? TextField(
                            key: const Key('host-field'),
                            controller: field,
                            focusNode: fieldFocus,
                          )
                        : InkWell(
                            onTap: () => tappedRows.add(i),
                            child: Text('row $i'),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: PhotoPanel(
                    controller: controller,
                    busy: busy,
                    hidden: hidden,
                    bottomReserve: bottomReserve,
                    scrollController: scroll,
                    look: look,
                    onSelected: selections.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(build());
    await settleLoads(tester);
  }

  /// Lets the preferences load and the previews' post-frame reads finish.
  static Future<void> settleLoads(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder get tabFinder => find.byKey(PhotoPanel.tabKey);

Rect tabRect(WidgetTester tester) => tester.getRect(tabFinder);

/// The words page: below the AppBar, the whole width.
Rect pageRect(WidgetTester tester) => tester.getRect(find.byKey(const Key('host-list')));

Finder get panelFinder => find.byKey(PhotoPanel.panelKey);

Rect panelRect(WidgetTester tester) => tester.getRect(panelFinder);

Finder smallPhoto(String id) => find.byKey(PhotoPanel.smallPhotoKey(id));

/// The main screen under a router with the Notes page, so the panel's
/// expand control and a drag to full-open can open Notes (owner, 2026-10-15).
GoRouter mainScreenRouter() => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WordInputScreen(),
        routes: [
          GoRoute(
            path: 'notes',
            builder: (context, state) => NotesScreen(
                selectedId: state.uri.queryParameters['selected-id']),
          ),
        ],
      ),
    ]);
