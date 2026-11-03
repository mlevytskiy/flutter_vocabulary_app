import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/theme/app_decor.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/dashed_add_button.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/word_context_field.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

import 'seed_collections.dart';

/// Words: word context field (owner 2026-11-03): the context under the Word
/// and Translation fields — text + edit icon, "+add context", and editing.
void main() {
  Finder contextField() => find.byKey(WordContextField.fieldKey);

  group('WordContextField', () {
    Future<List<String>> pump(WidgetTester tester, String text) async {
      final saved = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(children: [
              WordContextField(
                contextText: text,
                onSave: (t) => setState(() {
                  saved.add(t);
                  text = t;
                }),
              ),
              const TextField(key: Key('other')),
            ]),
          ),
        ),
      ));
      return saved;
    }

    testWidgets('a context shows as text with an edit icon', (tester) async {
      await pump(tester, 'a tenacious fighter');
      expect(find.byKey(WordContextField.textKey), findsOneWidget);
      expect(find.textContaining('a tenacious fighter'), findsOneWidget);
      expect(find.byKey(WordContextField.editKey), findsOneWidget);
      expect(find.byType(DashedAddButton), findsNothing);
      expect(contextField(), findsNothing);

      await tester.tap(find.byKey(WordContextField.editKey));
      await tester.pump();
      expect(contextField(), findsOneWidget);
      expect(tester.widget<TextField>(contextField()).controller!.text,
          'a tenacious fighter');
    });

    testWidgets('no context shows the dashed +add context button',
        (tester) async {
      await pump(tester, '');
      expect(find.byType(DashedAddButton), findsOneWidget);
      expect(find.text('+add context'), findsOneWidget);
      expect(find.byKey(WordContextField.editKey), findsNothing);

      await tester.tap(find.text('+add context'));
      await tester.pump();
      await tester.pump();
      expect(contextField(), findsOneWidget);
      final field = tester.widget<TextField>(contextField());
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.decoration!.border, isA<OutlineInputBorder>());
    });

    testWidgets('focus loss saves; clearing brings +add context back',
        (tester) async {
      final saved = await pump(tester, '');
      await tester.tap(find.text('+add context'));
      await tester.pump();
      await tester.enterText(contextField(), '  in use  ');
      await tester.tap(find.byKey(const Key('other')));
      await tester.pump();
      expect(saved, ['in use']);
      expect(find.textContaining('in use'), findsOneWidget);
      expect(find.byKey(WordContextField.editKey), findsOneWidget);

      await tester.tap(find.byKey(WordContextField.editKey));
      await tester.pump();
      await tester.enterText(contextField(), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saved, ['in use', '']);
      expect(find.text('+add context'), findsOneWidget);
    });

    testWidgets('the OK tick saves; the button is the context violet',
        (tester) async {
      final saved = await pump(tester, '');
      final button =
          tester.widget<DashedAddButton>(find.byType(DashedAddButton));
      expect(button.color, isNot(AppDecor.classic.addAccent));

      await tester.tap(find.text('+add context'));
      await tester.pump();
      await tester.pump();
      await tester.enterText(contextField(), 'met in a film');
      await tester.tap(find.byKey(WordContextField.okKey));
      await tester.pump();
      expect(saved, ['met in a film']);
      expect(contextField(), findsNothing);
      expect(find.textContaining('met in a film'), findsOneWidget);
    });
  });

  group('on the Words screen', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUpAll(() async {
      final saved = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        await Isar.initializeIsarCore(download: true);
      } finally {
        HttpOverrides.global = saved;
      }
    });

    testWidgets('shows each row context and saves a typed one', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late Directory dir;
      late CollectionStore store;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('word_context_field_test');
        store = await CollectionStore.open(directory: dir.path);
        final collection = WordCollection.create()
          ..words = [
            WordPair(
                word: 'tenacious',
                translation: 'наполегливий',
                context: 'a tenacious fighter',
                contextKind: ContextKind.ai),
            WordPair(word: 'cat', translation: 'кіт'),
          ];
        await seedCollection(store, collection);
        await store.setCurrentCollectionId(collection.collectionId);
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
      });
      final container = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
      ]);
      await tester.runAsync(() async {
        await container.read(wordsProvider.future);
        container.read(wordDetailModeProvider);
        await container.read(wordDetailModeProvider.notifier).loaded;
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordsScreen()),
      ));
      container
          .read(wordsProvider.notifier)
          .setPairs(List.of(container.read(wordsProvider).value!.words));
      await tester.pump();
      await tester.pump();

      List<WordPair> words() => container.read(wordsProvider).value!.words;

      // Row 0 has a context: text + edit icon. Row 1 has none.
      expect(find.textContaining('a tenacious fighter'), findsOneWidget);
      expect(find.byKey(WordContextField.editKey), findsOneWidget);
      expect(find.byKey(WordContextField.addKey), findsWidgets);

      // Fill row 1's context and submit: saved to the word, shown as text.
      await tester.tap(find.text('+add context').first);
      await tester.pump();
      await tester.pump();
      await tester.enterText(contextField(), 'the cat sat');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(words()[1].context, 'the cat sat');
      expect(words()[1].contextKind, ContextKind.source);
      expect(words()[0].context, 'a tenacious fighter');
      expect(find.textContaining('the cat sat'), findsOneWidget);
      expect(find.byKey(WordContextField.editKey), findsNWidgets(2));

      // Clearing it returns "+add context" and empties the word's context.
      await tester.tap(find.byKey(WordContextField.editKey).at(1));
      await tester.pump();
      await tester.pump();
      await tester.enterText(contextField(), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(words()[1].context, '');
      expect(words()[1].contextKind, ContextKind.none);
      expect(find.textContaining('the cat sat'), findsNothing);
      expect(find.byKey(WordContextField.editKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
