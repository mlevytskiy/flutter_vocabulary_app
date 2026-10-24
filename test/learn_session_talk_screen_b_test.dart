import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/core/theme/themes/themes.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_text.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_widgets.dart';

import 'learn_session_talk_handsfree_test.dart' show EngineSpeech, HoldTts;
import 'learn_session_talk_test.dart' show FakeTalkApi;

/// talk-screen-b (owner, 2026-10-24): Talk with AI as Direction B — long
/// bubbles, the practice words highlighted and tappable (the Words screen's
/// popup, read-only), one line of all the words, karaoke and the pause ring.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const long = 'You walked down to the old harbour in the morning, and the light was soft and gold. '
      'The streets near the water were already crowded with people selling fish, bread and flowers. '
      'Someone told you the last ferry ticket of the day sells out by noon, so you hurried. '
      'Then you stopped at a tiny café and wandered for a while among the boats. '
      'Tell me, what did you see first when you arrived, and how did it make you feel?';

  group('karaoke and highlight spans (pure)', () {
    final wander = WordPair(word: 'wander', translation: 'блукати', rowId: 'w');
    test('karaokeSplit snaps to the end of the word being said', () {
      const text = 'I wandered around the harbour';
      expect(karaokeSplit(text, 0), 0);
      expect(karaokeSplit(text, 1), text.length);
      expect(karaokeSplit(text, 0.1), 'I wandered'.length);
      expect(karaokeSplit(text, -1), 0);
      expect(karaokeSplit(text, 2), text.length);
    });

    test('talkSpans marks the practice words, inflected forms too, and the spoken part', () {
      final spans = talkSpans('I wandered around', [wander], spokenEnd: 'I wandered'.length);
      expect([for (final s in spans) s.text], ['I ', 'wandered', ' around']);
      expect([for (final s in spans) s.word?.rowId], [null, 'w', null]);
      expect([for (final s in spans) s.spoken], [true, true, false]);
    });

    test('talkSpans without karaoke is all spoken; a split inside a word cuts it', () {
      expect(talkSpans('Wander off', [wander]).every((s) => s.spoken), isTrue);
      final cut = talkSpans('wandered', [wander], spokenEnd: 3);
      expect([for (final s in cut) (s.text, s.spoken, s.word != null)], [('wan', true, true), ('dered', false, true)]);
    });

    test('karaokeDuration grows with the text', () {
      expect(karaokeDuration(long) > karaokeDuration('Hi there.'), isTrue);
      expect(karaokeDuration('Hi') >= const Duration(seconds: 1), isTrue);
    });
  });

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
    dir = Directory.systemTemp.createTempSync('learn_session_talk_screen_b_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  late FakeTalkApi api;
  late EngineSpeech speech;
  late HoldTts tts;

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump();
    }
  }

  Future<void> open(
    WidgetTester t, {
    String opening = 'Tell me more.',
    ThemeData? theme,
    double textScale = 1,
    List<String> words = const ['crowded', 'ticket', 'wander'],
  }) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    api = FakeTalkApi()..answers.add(TalkTurn(reply: opening, target: words.first));
    final log = <String>[];
    speech = EngineSpeech(log);
    tts = HoldTts(log);
    late String id;
    await t.runAsync(() async {
      final c = await store.create(keep: true, name: 'Lisbon trip');
      c.words = [
        for (final (i, w) in words.indexed) WordPair(word: w, translation: 't-$w', rowId: 'r${i + 1}'),
      ];
      await store.put(c);
      id = c.collectionId;
    });
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
      speechInputProvider.overrideWithValue(speech),
      pronunciationServiceProvider.overrideWithValue(tts),
    ]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TalkScreen(collectionId: id, split: false),
      ),
    ));
    await settle(t);
  }

  Future<void> reply(WidgetTester t, String text) async {
    await t.enterText(find.byType(TextField), text);
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    await settle(t);
  }

  /// The highlighted spans of the bubble [index] (TextSpans with a word style).
  List<TextSpan> spansOf(WidgetTester t, int index) {
    final text = t.widget<Text>(find.descendant(of: find.byKey(talkBubbleKey(index)), matching: find.byType(Text)).first);
    final out = <TextSpan>[];
    text.textSpan!.visitChildren((s) {
      if (s is TextSpan && s.text != null) out.add(s);
      return true;
    });
    return out;
  }

  for (final spec in appThemes) {
    testWidgets('a long AI message fits 393×852 at text scale 1.3 in ${spec.name}', (t) async {
      await open(t, opening: long, theme: spec.build(), textScale: 1.3);
      expect(find.text(long), findsOneWidget);
      final bubble = t.getSize(find.byKey(talkBubbleKey(0)));
      expect(bubble.width, lessThanOrEqualTo(393 * 0.84 + 0.5));
      expect(find.text('Emma'), findsOneWidget);
      expect(find.textContaining('Lisbon trip'), findsOneWidget);
      await reply(t, 'I wandered around the crowded harbour for a long time, the light was lovely and soft');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('practice words are highlighted in AI and learner messages, inflected forms too', (t) async {
    await open(t, opening: 'Have you wandered around a crowded market?');
    final ai = spansOf(t, 0);
    final plainStyle = ai.firstWhere((s) => s.text!.startsWith('Have')).style;
    final wandered = ai.firstWhere((s) => s.text == 'wandered');
    final crowded = ai.firstWhere((s) => s.text == 'crowded');
    expect(wandered.recognizer, isNotNull);
    expect(crowded.recognizer, isNotNull);
    expect(wandered.style?.fontWeight, isNot(plainStyle?.fontWeight));
    expect(wandered.style?.decoration, TextDecoration.underline);
    await reply(t, 'Yes, I wandered there and bought a ticket');
    final mine = spansOf(t, 1);
    expect(mine.firstWhere((s) => s.text == 'wandered').recognizer, isNotNull);
    expect(mine.firstWhere((s) => s.text == 'ticket').recognizer, isNotNull);
    expect(mine.firstWhere((s) => s.text!.startsWith('Yes')).recognizer, isNull);
  });

  testWidgets("tapping a highlighted word opens the Words popup with its translation, read-only", (t) async {
    await open(t, opening: 'Was the market crowded today?');
    expect(find.text('t-crowded'), findsNothing);
    await t.tapOnText(find.textRange.ofSubstring('crowded', descendentOf: find.byKey(talkBubbleKey(0))));
    await t.pump();
    await t.pump();
    expect(find.text('t-crowded'), findsOneWidget);
    expect(find.text('No translations loaded yet. Tap to load.'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(find.text('t-crowded'), findsNothing);
  });

  testWidgets('tapping a word of the strip opens the same popup', (t) async {
    await open(t);
    await t.tap(find.descendant(of: find.byKey(talkStripKey), matching: find.text('ticket')));
    await t.pump();
    await t.pump();
    expect(find.text('t-ticket'), findsOneWidget);
    expect(find.text('No translations loaded yet. Tap to load.'), findsOneWidget);
  });

  testWidgets('the strip is one horizontal scrolling row of all the words', (t) async {
    await open(t, words: [for (var i = 0; i < 14; i++) 'word$i']);
    final strip = t.widget<ListView>(find.byKey(talkStripKey));
    expect(strip.scrollDirection, Axis.horizontal);
    expect(find.descendant(of: find.byKey(talkStripKey), matching: find.byType(Wrap)), findsNothing);
    expect(find.descendant(of: find.byKey(talkStripKey), matching: find.text('word0')), findsOneWidget);
    await t.drag(find.byKey(talkStripKey), const Offset(-2000, 0));
    await t.pump();
    expect(find.descendant(of: find.byKey(talkStripKey), matching: find.text('word13')), findsOneWidget);
  });

  testWidgets('the ring counts down the pause after words were heard', (t) async {
    await open(t);
    tts.finishSpeaking();
    await t.pump();
    await t.pump();
    expect(t.widget<TalkRing>(find.byType(TalkRing)).progress, 0);
    speech.partial('I took the bus');
    await t.pump();
    expect(find.text('I took the bus'), findsWidgets);
    await t.pump(const Duration(milliseconds: 1500));
    expect(t.widget<TalkRing>(find.byType(TalkRing)).progress, greaterThan(0.3));
    expect(find.text(talkSendingInText(3)), findsOneWidget);
  });

  testWidgets('the line being spoken colours its spoken words; done, it is plain again', (t) async {
    const line = 'one two three four five six seven eight nine ten';
    await open(t, opening: line);
    await t.pump(karaokeDuration(line) ~/ 2);
    Color? colour(TextSpan s) => s.style?.color;
    var spans = spansOf(t, 0);
    expect(colour(spans.first), isNot(colour(spans.last)));
    tts.finishSpeaking();
    await t.pump();
    await t.pump();
    spans = spansOf(t, 0);
    expect(spans.map(colour).toSet(), hasLength(1));
  });
}
