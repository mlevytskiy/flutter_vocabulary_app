import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

import 'learn_session_talk_test.dart' show FakeTalkApi;

/// learn-redesign T18 (AC-20, AC-21, AC-24): the Talk with AI screen over a
/// fake talk service and a temporary store.
class _Fake extends WordsNotifier {
  _Fake(this.c);
  final WordCollection c;
  @override
  Future<WordCollection> build() async => c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late CollectionStore store;
  late StoryRunStore runs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    dir = Directory.systemTemp.createTempSync('learn_session_talk_screen_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  late FakeTalkApi api;
  late String id;
  late GoRouter router;

  /// Lets the notifier's real async work (Isar, prefs) finish.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump();
    }
  }

  Future<void> open(WidgetTester t, {List<String> words = const ['crowded', 'ticket', 'bus']}) async {
    SharedPreferences.setMockInitialValues({});
    api = FakeTalkApi();
    await t.runAsync(() async {
      final c = await store.create(keep: true);
      c.words = [for (var i = 0; i < words.length; i++) WordPair(word: words[i], translation: 't-${words[i]}', rowId: 'r${i + 1}')];
      await store.put(c);
      id = c.collectionId;
    });
    router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/words', builder: (_, __) => const SizedBox(), routes: [
        GoRoute(path: 'table', builder: (_, __) => const SizedBox(), routes: [
          GoRoute(path: 'talk', builder: (_, s) => TalkScreen(collectionId: s.uri.queryParameters['collectionId'], split: false)),
          GoRoute(path: 'results', builder: (_, __) => const Scaffold(body: Text('results screen'))),
        ]),
      ]),
    ]);
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    router.push('/words/table/talk?collectionId=$id');
    await t.pump();
    // Flutter 3.47's default Android page transition slides; let it finish.
    await t.pump(const Duration(milliseconds: 800));
    await settle(t);
  }

  Future<void> reply(WidgetTester t, String text) async {
    await t.enterText(find.byType(TextField), text);
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    await settle(t);
  }

  testWidgets('opening shows the AI bubble, counter and the word strip', (t) async {
    await open(t);
    expect(find.text('Talk with AI'), findsOneWidget);
    expect(find.text('0 / 12'), findsOneWidget);
    expect(find.text('Tell me more.'), findsOneWidget);
    expect(find.text('crowded'), findsOneWidget);
    expect(find.text('Type a reply…'), findsOneWidget);
    expect(find.text('Planning your mission…'), findsNothing);
  });

  testWidgets('a reply adds a learner bubble and ticks the used word', (t) async {
    await open(t);
    await reply(t, 'The bus was crowded');
    expect(find.text('The bus was crowded'), findsOneWidget);
    expect(find.text('crowded ✓'), findsOneWidget);
    expect(find.text('bus ✓'), findsOneWidget);
    expect(find.text('ticket'), findsOneWidget);
    expect(find.text('1 / 12'), findsOneWidget);
  });

  testWidgets('an AI reply containing a word ticks nothing', (t) async {
    await open(t);
    api.answers.add(TalkTurn(reply: 'Was it crowded?', target: 'crowded'));
    await reply(t, 'hello there');
    expect(find.text('Was it crowded?'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);
  });

  testWidgets('Hint is enabled after 2 replies without the target and shows it', (t) async {
    await open(t);
    OutlinedButton hint() => t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Hint'));
    expect(hint().onPressed, isNull);
    await reply(t, 'one');
    await reply(t, 'two');
    expect(hint().onPressed, isNotNull);
    await t.tap(find.text('Hint'));
    await t.pump();
    expect(find.textContaining('Try using: '), findsOneWidget);
  });

  testWidgets('End talk finishes and opens the results', (t) async {
    await open(t);
    await reply(t, 'The bus was crowded');
    await t.tap(find.text('End talk'));
    await t.pump();
    for (var i = 0; i < 20 && find.text('results screen').evaluate().isEmpty; i++) {
      await settle(t);
    }
    await t.pumpAndSettle();
    expect(find.text('results screen'), findsOneWidget);
  });

  testWidgets('Back with messages asks first; Stay keeps the talk', (t) async {
    await open(t);
    await t.pageBack();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Leave the talk? Words used so far are not saved.'), findsOneWidget);
    await t.tap(find.text('Stay'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Talk with AI'), findsOneWidget);
    await t.pageBack();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Leave'));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Talk with AI'), findsNothing);
  });

  testWidgets('AC-24: the day limit shows its line and Back', (t) async {
    SharedPreferences.setMockInitialValues({});
    api = FakeTalkApi();
    await t.runAsync(() async {
      final c = await store.create(keep: true);
      c.words = [WordPair(word: 'bus', translation: 'автобус', rowId: 'r1')];
      await store.put(c);
      id = c.collectionId;
    });
    api.answers.add(TalkApiException(TalkApiError.dayLimit, 'limit'));
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp(home: TalkScreen(collectionId: id, split: false))));
    await settle(t);
    expect(find.text(talkDayLimitMessage), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('an error keeps the typed text and Retry sends it again', (t) async {
    await open(t);
    api.answers.add(TalkApiException(TalkApiError.failed, 'boom'));
    await reply(t, 'my reply');
    expect(find.text(talkFailedMessage), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'my reply');
    final bubbles = find.descendant(of: find.byType(ListView).first, matching: find.text('my reply'));
    expect(bubbles, findsNothing);
    await t.tap(find.text('Retry'));
    await t.pump();
    await settle(t);
    expect(find.text(talkFailedMessage), findsNothing);
    expect(bubbles, findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('the sheet\'s Talk with AI card opens TalkRoute with split', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = WordCollection.create()
      ..words = [for (var i = 0; i < 5; i++) WordPair(word: 'word$i', translation: 'слово$i')..rowId = 'r$i'];
    final container = ProviderContainer(overrides: [wordsProvider.overrideWith(() => _Fake(c))]);
    addTearDown(container.dispose);
    await t.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordsProvider.future);
    });
    String? talkUri;
    final r = GoRouter(initialLocation: '/words/table', routes: [
      GoRoute(path: '/words/table', builder: (_, __) => const WordsTableScreen(), routes: [
        GoRoute(
            path: 'talk',
            builder: (_, s) {
              talkUri = s.uri.toString();
              return const Scaffold(body: Text('talk screen'));
            }),
      ]),
    ]);
    addTearDown(r.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: r)));
    await t.pumpAndSettle();
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    await t.tap(find.text('Talk with AI'));
    await t.pumpAndSettle();
    expect(find.text('talk screen'), findsOneWidget);
    expect(talkUri, contains('split=false'));
  });
}
