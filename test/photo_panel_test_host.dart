import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/photo_panel_look.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photos_with_words.dart';

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

class PanelHost {
  PanelHost({
    List<PhotoWithWords>? photos,
    this.busy = false,
    this.bottomReserve = 80,
    this.look,
    this.rows = 50,
  }) : photos = ValueNotifier(photos ?? fakePhotos(3));

  final ValueNotifier<List<PhotoWithWords>> photos;
  final bool busy;
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
          photosWithWordsProvider.overrideWith((ref) {
            void update() => ref.state = photos.value;
            photos.addListener(update);
            ref.onDispose(() => photos.removeListener(update));
            return photos.value;
          }),
          sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
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
