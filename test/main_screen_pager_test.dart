import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/dialogue_page.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// get-words-from-subtitles-improvment T19: the main screen pages through the
/// session's dialogues after page 1 (SCR-01, SCR-02; AC-01, AC-02, AC-05,
/// AC-06, AC-10, AC-11).
void main() {
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

  WordPair pair(String id, String word, String translation,
          [String definition = '']) =>
      WordPair(
          word: word,
          translation: translation,
          definition: definition,
          rowId: id);

  FilmDialogue dialogue(String id, List<String> lines, List<String> rowIds) =>
      FilmDialogue()
        ..id = id
        ..lines = lines
        ..wordRowIds = rowIds;

  /// Every bold run of text inside [finder].
  List<String> boldIn(WidgetTester tester, Finder finder) {
    final out = <String>[];
    for (final rich in tester.widgetList<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.fontWeight == FontWeight.bold) {
          out.add(span.text!);
        }
        return true;
      });
    }
    return out;
  }

  group('DialoguePage', () {
    Future<void> pumpPage(WidgetTester tester, FilmDialogue d, List<WordPair> words) =>
        tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: DialoguePage(dialogue: d, words: words)),
          ),
        ));

    testWidgets('bolds every place of every dialogue word and lists them (AC-02, AC-05)',
        (tester) async {
      final d = dialogue('d1', ['- Is it in the attic?', '- Attics are dusty; the attic is.'],
          ['r1', 'r2']);
      await pumpPage(tester, d, [
        pair('r1', 'attic', 'горище', 'A room under the roof.'),
        pair('r2', 'dusty', 'запорошений'),
        pair('r3', 'is', 'є'),
      ]);

      expect(boldIn(tester, find.byType(DialoguePage)),
          ['attic', 'Attics', 'dusty', 'attic']);
      expect(find.text('горище'), findsOneWidget);
      expect(find.text('A room under the roof.'), findsOneWidget);
      expect(find.text('запорошений'), findsOneWidget);
      expect(find.text('є'), findsNothing, reason: 'not a dialogue word');
    });

    testWidgets('shows the current form of each word (AC-11)', (tester) async {
      final d = dialogue('d1', ['The attic.'], ['r1']);
      await pumpPage(tester, d, [pair('r1', 'attic', 'мансарда')]);
      expect(find.text('мансарда'), findsOneWidget);
    });
  });

  group('the main screen', () {
    // Below the rows: a single-line text field scrolls itself sideways.
    // As settings_fab_alignment_test.dart: let the screen's timers run out,
    // then unmount it.
    Future<void> finish(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> swipeLeft(WidgetTester tester) async {
      await tester.flingFrom(const Offset(300, 600), const Offset(-250, 0), 2000);
      await tester.pumpAndSettle();
    }

    late Directory dir;
    late SessionStore store;

    Future<ProviderContainer> pumpScreen(WidgetTester tester, Session s) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('main_screen_pager_test');
        store = await SessionStore.open(directory: dir.path);
        s.lastLocalModifiedAt = DateTime.now();
        await store.put(s);
        await store.setCurrentSessionId(s.sessionId);
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
      });
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
      ]);
      addTearDown(container.dispose);
      await tester
          .runAsync(() => container.read(wordInputNotifierProvider.future));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordInputScreen()),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('without dialogues: no pager, as today (AC-01)', (tester) async {
      await pumpScreen(
          tester, Session.create()..words = [pair('r1', 'attic', 'горище')]);
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(DialoguePage), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('two dialogues: three pages in order; a word in both is bold on both (AC-02, AC-06)',
        (tester) async {
      await pumpScreen(
          tester,
          Session.create()
            ..words = [
              pair('r1', 'reluctant', 'неохочий'),
              pair('r2', 'fog', 'туман'),
            ]
            ..dialogues = [
              dialogue('d1', ['I was reluctant.'], ['r1']),
              dialogue('d2', ['Reluctant in the fog.'], ['r1', 'r2']),
              dialogue('d3', ['Hidden.'], [])..hidden = true,
            ]);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget, reason: 'page 1 first');

      await swipeLeft(tester);
      await tester.pumpAndSettle();
      expect(find.text('I was reluctant.', findRichText: true), findsOneWidget);
      expect(boldIn(tester, find.byType(DialoguePage)), ['reluctant']);
      expect(find.byTooltip('Settings'), findsNothing,
          reason: 'the buttons belong to page 1');

      await swipeLeft(tester);
      await tester.pumpAndSettle();
      expect(boldIn(tester, find.byType(DialoguePage)), ['Reluctant', 'fog']);
      expect(find.text('туман'), findsOneWidget);

      await swipeLeft(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hidden.', findRichText: true), findsNothing,
          reason: 'a hidden dialogue has no page');
      await finish(tester);
    });

    testWidgets('an edited translation shows on the page (AC-11)', (tester) async {
      final container = await pumpScreen(
          tester,
          Session.create()
            ..words = [pair('r1', 'fog', 'туман')]
            ..dialogues = [dialogue('d1', ['The fog.'], ['r1'])]);

      final notifier = container.read(wordInputNotifierProvider.notifier);
      notifier.updateAt(0, translation: 'імла');
      await tester.runAsync(notifier.flush);
      await tester.pump();
      await swipeLeft(tester);
      await tester.pumpAndSettle();
      expect(find.text('імла'), findsOneWidget);
      await finish(tester);
    });
  });
}
