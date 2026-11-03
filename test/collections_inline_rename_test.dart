import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_icon.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/collections/inline_rename.dart';
import 'package:flutter_vocabulary_app/features/collections/name_dialog.dart';
import 'package:flutter_vocabulary_app/features/collections/recycle_bin_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

/// collection inline rename (owner, 2026-11-03): a long press released
/// without moving, begun on a name, renames that item in place.

class _FakeInput extends WordsNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  final opened = <String>[];
  @override
  Future<WordCollection> build() async => collection;
  @override
  Future<bool> open(String id) async {
    opened.add(id);
    return true;
  }
}

class _FakeStore implements CollectionStore {
  final calls = <String>[];

  @override
  Future<FilingResult> rename(String id, String name) async {
    calls.add('rename $id $name');
    return FilingResult.done;
  }

  @override
  Future<FilingResult> move(String id, String? target, {int? at}) async {
    calls.add('move $id -> $target');
    return FilingResult.done;
  }

  @override
  Future<FilingResult> reorder(String id, int index) async {
    calls.add('reorder $id $index');
    return FilingResult.done;
  }

  @override
  Future<WordCollection?> byId(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CollectionFolder _folder(String id, String name) => CollectionFolder()
  ..folderId = id
  ..name = name;

WordCollection _coll(String name) => WordCollection.create()
  ..name = name
  ..words = [WordPair(word: 'w', translation: 't')];

void main() {
  final english = _folder('f1', 'English course');
  final phrasal = _coll('Phrasal verbs');
  final films = _coll('Films words');
  final idioms = _coll('Idioms');
  late _FakeStore store;
  late _FakeInput input;

  final field = find.byKey(InlineNameField.fieldKey);

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore();
    await t.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        binItemsProvider.overrideWith((ref) => Stream.value(const [])),
        wordsProvider.overrideWith(() => input = _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(films),
              LevelItem.collection(idioms),
            ])),
        collectionLevelProvider('f1').overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(home: CollectionsScreen()),
    ));
    await t.pump();
    await t.pump();
  }

  /// A long press on [at], let go without moving.
  Future<void> hold(WidgetTester t, Offset at) async {
    final g = await t.startGesture(at);
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.up();
    await t.pump();
    await t.pump();
  }

  Future<void> holdName(WidgetTester t, String name) =>
      hold(t, t.getCenter(find.text(name)));

  TextEditingController controller(WidgetTester t) =>
      t.widget<TextField>(field).controller!;

  testWidgets('a long press on the name opens the field, all text selected',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    expect(field, findsOneWidget);
    final c = controller(t);
    expect(c.text, 'Films words');
    expect(c.selection,
        const TextSelection(baseOffset: 0, extentOffset: 'Films words'.length));
    expect(t.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    expect(t.widget<TextField>(field).style, CollectionIcon.nameStyle);
    expect(t.testTextInput.isVisible, isTrue);
  });

  testWidgets('a long press on the picture opens nothing', (t) async {
    await pump(t);
    final name = t.getRect(find.text('Films words'));
    await hold(t, Offset(name.center.dx, name.top - 30));
    expect(field, findsNothing);
    expect(store.calls, isEmpty);
  });

  testWidgets('a long press that moves still drags and opens no field',
      (t) async {
    await pump(t);
    final g = await t.startGesture(t.getCenter(find.text('Films words')));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 30));
    await t.pump();
    await g.moveTo(t.getCenter(find.text('English course')));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(field, findsNothing);
    expect(store.calls, ['move ${films.collectionId} -> f1']);
  });

  testWidgets('a tap outside saves the trimmed name and shows it', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, '  Movie words  ');
    await t.tapAt(const Offset(700, 400));
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
    expect(field, findsNothing);
    expect(find.text('Movie words'), findsOneWidget);
  });

  testWidgets('a tap inside the field moves the cursor and keeps editing',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    final r = t.getRect(field);
    await t.tapAt(Offset(r.left + 6, r.center.dy));
    await t.pump(const Duration(milliseconds: 400));
    expect(field, findsOneWidget);
    expect(store.calls, isEmpty);
    final c = controller(t);
    // All was selected; the tap put the cursor in instead.
    expect(c.selection.isCollapsed, isTrue);
  });

  testWidgets('a drag inside the field selects text and keeps editing',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    final r = t.getRect(field);
    await t.tapAt(Offset(r.left + 6, r.center.dy));
    await t.pump(const Duration(milliseconds: 400));
    final g = await t.startGesture(Offset(r.left + 6, r.center.dy),
        kind: PointerDeviceKind.mouse);
    await g.moveTo(Offset(r.right - 6, r.center.dy));
    await g.up();
    await t.pump();
    expect(field, findsOneWidget);
    expect(store.calls, isEmpty);
    expect(controller(t).selection.isCollapsed, isFalse);
  });

  group('a tap on a just-renamed name', () {
    Future<void> renameFolder(WidgetTester t) async {
      await pump(t);
      await holdName(t, 'English course');
      await t.enterText(field, 'French course');
      await t.tapAt(const Offset(700, 400)); // closes, opens nothing
      await t.pump();
      await t.pump();
      expect(field, findsNothing);
    }

    final topLevel = find.text('Idioms');

    testWidgets('opens the field again, not the folder', (t) async {
      await renameFolder(t);
      await t.tap(find.text('French course'));
      await t.pump();
      await t.pump();
      expect(field, findsOneWidget);
      expect(controller(t).text, 'French course');
      expect(topLevel, findsOneWidget);
    });

    testWidgets('opens the folder after a touch elsewhere', (t) async {
      await renameFolder(t);
      await t.tapAt(const Offset(700, 400));
      await t.pump();
      await t.tap(find.text('French course'));
      await t.pump();
      await t.pump();
      expect(field, findsNothing);
      expect(topLevel, findsNothing);
    });

    testWidgets('on the picture opens the folder', (t) async {
      await renameFolder(t);
      final r = t.getRect(find.text('French course'));
      await t.tapAt(Offset(r.center.dx, r.top - 30));
      await t.pump();
      await t.pump();
      expect(field, findsNothing);
      expect(topLevel, findsNothing);
    });

    testWidgets('on a fresh screen a tap on a name opens the folder',
        (t) async {
      await pump(t);
      await t.tap(find.text('English course'));
      await t.pump();
      await t.pump();
      expect(field, findsNothing);
      expect(topLevel, findsNothing);
      await t.pump(const Duration(seconds: 2)); // let the tap's timers end
    });
  });

  testWidgets('Done saves', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
    expect(field, findsNothing);
  });

  testWidgets('an empty name goes back to the old one', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, '   ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(store.calls, isEmpty);
    expect(field, findsNothing);
    expect(find.text('Films words'), findsOneWidget);
  });

  testWidgets('an unchanged name writes nothing', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.tapAt(const Offset(700, 400));
    await t.pump();
    expect(store.calls, isEmpty);
    expect(field, findsNothing);
  });

  testWidgets('Esc cancels', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(store.calls, isEmpty);
    expect(field, findsNothing);
    expect(find.text('Films words'), findsOneWidget);
  });

  testWidgets('a name the rules refuse keeps the field open with the error',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'x' * 61);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(store.calls, isEmpty);
    expect(field, findsOneWidget);
    expect(find.text(nameProblemMessage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the current collection with a two-line name fits its cell',
      (t) async {
    await pump(t);
    await holdName(t, 'Phrasal verbs');
    await t.enterText(field, 'Phrasal verbs for the second unit');
    await t.pump();
    expect(field, findsOneWidget);
    expect(find.text('current'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a long press on another name first only saves, then edits it',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    await holdName(t, 'Idioms');
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
    expect(field, findsNothing);
    await holdName(t, 'Idioms');
    expect(field, findsOneWidget);
    expect(controller(t).text, 'Idioms');
    expect(find.text('Movie words'), findsOneWidget);
  });

  testWidgets('a folder renames in place too', (t) async {
    await pump(t);
    await holdName(t, 'English course');
    await t.enterText(field, 'French course');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename f1 French course']);
    expect(find.text('French course'), findsOneWidget);
  });

  testWidgets('a tap on another collection only saves, it opens nothing',
      (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    // The shield takes this touch, so the tap does not reach the text.
    await t.tap(find.text('Idioms'), warnIfMissed: false);
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
    expect(input.opened, isEmpty);
    expect(field, findsNothing);
    expect(find.text('Movie words'), findsOneWidget);
    // The next tap works as usual: the folder opens.
    await t.tap(find.text('English course'));
    await t.pump();
    await t.pump();
    expect(find.text('Idioms'), findsNothing);
  });

  testWidgets('a tap on the edited tile saves and does not open it', (t) async {
    await pump(t);
    await holdName(t, 'English course');
    await t.enterText(field, 'French course');
    final r = t.getRect(field);
    await t.tapAt(Offset(r.center.dx, r.top - 30)); // the folder picture
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename f1 French course']);
    // Still the top level: the folder did not open.
    expect(find.text('Phrasal verbs'), findsOneWidget);
  });

  testWidgets('the keyboard closing saves', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    expect(field, findsOneWidget);
    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    await t.pump();
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
    expect(field, findsNothing);
  });

  testWidgets('the edited tile stays above the keyboard', (t) async {
    // Small screen: the last row sits low.
    await pump(t);
    await t.binding.setSurfaceSize(const Size(240, 600));
    await t.pump();
    await holdName(t, 'Idioms');
    t.view.viewInsets = FakeViewPadding(bottom: 400 * t.view.devicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    await t.pump();
    expect(field, findsOneWidget);
    expect(t.getRect(field).bottom, lessThan(600 - 400));
  });

  testWidgets('leaving the screen saves', (t) async {
    await pump(t);
    await holdName(t, 'Films words');
    await t.enterText(field, 'Movie words');
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(store.calls, ['rename ${films.collectionId} Movie words']);
  });
}
