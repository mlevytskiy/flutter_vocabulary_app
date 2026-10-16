import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_dialogs.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_icon.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/collections/fly_to_bin.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:go_router/go_router.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  @override
  Future<WordCollection> build() async => collection;
}

class _FakeStore implements CollectionStore {
  final binned = <String>[];
  final previewed = <String>[];
  String? stayedName;

  @override
  Future<BinPreview?> binPreview(String id) async {
    previewed.add(id);
    return null;
  }

  @override
  Future<({BinResult result, String? stayedName})> bin(String id,
      {DateTime? now}) async {
    binned.add(id);
    return (result: BinResult.done, stayedName: stayedName);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WordCollection _coll(String name) => WordCollection.create()
  ..name = name
  ..words = [WordPair(word: 'w', translation: 't')];

void main() {
  final english = CollectionFolder()
    ..folderId = 'f1'
    ..name = 'English course';
  final phrasal = _coll('Phrasal verbs');
  final films = _coll('Films words');
  late _FakeStore store;

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore();
    await t.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        wordInputNotifierProvider.overrideWith(() => _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(films),
            ])),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/collections', routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('MAIN'),
            routes: [
              GoRoute(
                  path: 'collections',
                  builder: (_, __) => const CollectionsScreen()),
              GoRoute(
                  path: 'recycle-bin',
                  builder: (_, __) => const Text('BIN SCREEN')),
            ],
          ),
        ]),
      ),
    ));
    await t.pumpAndSettle();
  }

  final smallBins = find.byTooltip(CollectionIcon.binButtonTooltip);

  Future<void> binMenu(WidgetTester t, String option) async {
    await t.tap(find.byTooltip('Recycle bin'));
    await t.pumpAndSettle();
    await t.tap(find.text(option));
    await t.pumpAndSettle();
  }

  testWidgets('the bin button offers Go to recycle bin and Enable delete mode',
      (t) async {
    await pump(t);
    expect(smallBins, findsNothing);
    await t.tap(find.byTooltip('Recycle bin'));
    await t.pumpAndSettle();
    expect(find.text(goToBinText), findsOneWidget);
    expect(find.text(enableDeleteModeText), findsOneWidget);
  });

  testWidgets('Go to recycle bin opens it', (t) async {
    await pump(t);
    await binMenu(t, goToBinText);
    expect(find.text('BIN SCREEN'), findsOneWidget);
  });

  testWidgets(
      'delete mode: a small bin on every icon but the current; Disable hides them',
      (t) async {
    await pump(t);
    await binMenu(t, enableDeleteModeText);
    // the folder and "Films words"; not the current "Phrasal verbs"
    expect(smallBins, findsNWidgets(2));
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Phrasal verbs'),
                matching: find.byType(CollectionIcon)),
            matching: smallBins),
        findsNothing);

    await t.tap(find.byTooltip('Recycle bin'));
    await t.pumpAndSettle();
    expect(find.text(disableDeleteModeText), findsOneWidget);
    await t.tap(find.text(disableDeleteModeText));
    await t.pumpAndSettle();
    expect(smallBins, findsNothing);
  });

  testWidgets(
      'a small bin flies the picture to the bin button, then bins with no question',
      (t) async {
    await pump(t);
    await binMenu(t, enableDeleteModeText);
    final filmsBin = find.descendant(
        of: find.ancestor(
            of: find.text('Films words'), matching: find.byType(CollectionIcon)),
        matching: smallBins);
    final binCentre = t.getCenter(find.byTooltip('Recycle bin'));

    await t.tap(filmsBin);
    await t.pump();
    // mid-flight: a flying copy of the picture, the tile invisible, not yet binned
    await t.pump(flyToBinDuration * 0.5);
    final flying = find.byType(CollectionPicture);
    expect(flying, findsNWidgets(4)); // 3 tiles + the flying copy
    expect(store.binned, isEmpty);
    expect(
        find.ancestor(
            of: find.text('Films words'),
            matching: find.byWidgetPredicate(
                (w) => w is Opacity && w.opacity == 0)),
        findsOneWidget);

    // it closes in on the bin button and lands in it
    final midway = (t.getCenter(flying.last) - binCentre).distance;
    await t.pump(flyToBinDuration * 0.49);
    final last = (t.getCenter(flying.last) - binCentre).distance;
    expect(last, lessThan(midway));
    expect(last, lessThan(30));

    await t.pumpAndSettle();
    expect(store.binned, [films.collectionId]);
    expect(store.previewed, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CollectionPicture), findsNWidgets(3));
  });

  testWidgets('a folder holding the current collection says it stayed',
      (t) async {
    await pump(t);
    store.stayedName = 'Lesson 4';
    await binMenu(t, enableDeleteModeText);
    await t.tap(find.descendant(
        of: find.ancestor(
            of: find.text('English course'),
            matching: find.byType(CollectionIcon)),
        matching: smallBins));
    await t.pumpAndSettle();
    expect(store.binned, ['f1']);
    expect(find.text(stayedText('Lesson 4')), findsOneWidget);
  });
}
