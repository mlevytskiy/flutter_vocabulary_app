import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/core/theme/themes/themes.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_text.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz_card.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_recognition_panel.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_widgets.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_word_popup.dart';

import 'learn_session_talk_handsfree_test.dart' show EngineSpeech, HoldTts;
import 'learn_session_talk_test.dart' show FakeQuizData, FakeTalkApi, FakeTalkPicture;

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
  late _FakeTranslate translate;
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
    TalkMission? mission,
    TalkTurn? turn,
    FakeTalkPicture? pictures,
  }) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    translate = _FakeTranslate();
    api = FakeTalkApi()..answers.add(turn ?? TalkTurn(reply: opening, target: words.first, mission: mission));
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
      talkPictureServiceProvider.overrideWithValue(pictures ?? FakeTalkPicture()),
      googleTranslateServiceProvider.overrideWithValue(translate),
      learnApiServiceProvider.overrideWithValue(FakeQuizData()),
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
    final text =
        t.widget<Text>(find.descendant(of: find.byKey(talkBubbleKey(index)), matching: find.byType(Text)).first);
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
    expect(t.widget<TalkRing>(find.byType(TalkRing)).progress, greaterThan(0.12));
    expect(find.text(talkSendingInText(9)), findsOneWidget);
  });

  testWidgets('the voice\'s progress colours the spoken words; done, the line is plain again', (t) async {
    const line = 'one two three four five six seven eight nine ten';
    await open(t, opening: line);
    var spans = spansOf(t, 0);
    expect(tts.progress, isNotNull);
    tts.progress!(0.5);
    await t.pump();
    Color? colour(TextSpan s) => s.style?.color;
    spans = spansOf(t, 0);
    expect(colour(spans.first), isNot(colour(spans.last)));
    tts.finishSpeaking();
    await t.pump();
    await t.pump();
    spans = spansOf(t, 0);
    expect(spans.map(colour).toSet(), hasLength(1));
  });

  testWidgets('mixed choices keep the word strip; a speaking task starts listening at once (owner, 2026-10-24)', (t) async {
    await open(t,
        turn: const TalkTurn(
            reply: 'What will you do?', target: 'crowded', interaction: 'choice', choices: ['Stay here', 'Leave now']));
    tts.finishSpeaking();
    await t.pump();
    expect(speech.inits, 0, reason: 'a choice turn never records');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Stay here'), findsOneWidget);
    expect(find.descendant(of: find.byKey(talkStripKey), matching: find.text('ticket')), findsOneWidget,
        reason: 'the practice words show on choice turns too');
    api.answers.add(const TalkTurn(
        reply: 'Where next?', target: 'crowded', interaction: 'choice', choices: ['Find a bus', 'Walk home']));
    await t.tap(find.text('Stay here'));
    await t.pump();
    await settle(t);
    expect(api.calls.last.history.last.isChoice, isTrue);
    api.answers.add(const TalkTurn(
        reply: 'What is wrong?',
        target: 'crowded',
        interaction: 'speak',
        speakingPrompt: 'Explain why you cannot get on the bus.'));
    await t.tap(find.text('Find a bus'));
    await t.pump();
    await settle(t);
    tts.finishSpeaking();
    await t.pump();
    expect(find.text('Your turn to speak'), findsOneWidget);
    expect(find.text('Explain why you cannot get on the bus.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await settle(t);
    expect(speech.untilPauseCalls, 1, reason: 'the speaking turn listens as soon as the line was read');
    expect(find.text('2 / 9'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('mixed choices allow a custom answer and completed missions hide the mic', (t) async {
    await open(t,
        turn: const TalkTurn(
            reply: 'Choose a plan.', target: 'crowded', interaction: 'choice', choices: ['Stay here', 'Leave now']));
    tts.finishSpeaking();
    await t.pump();
    await t.tap(find.text('Say something else'));
    await t.pump();
    await settle(t);
    expect(find.byType(TextField), findsOneWidget);
    expect(speech.untilPauseCalls, 1, reason: 'Say something else listens at once');
    api.answers.add(const TalkTurn(reply: 'You found a way home.', target: 'crowded', interaction: 'complete'));
    await reply(t, 'Take a taxi');
    expect(api.calls.last.history.last.isChoice, isFalse);
    expect(find.text('See results'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a practice word in a choice is highlighted', (t) async {
    await open(t,
        turn: const TalkTurn(
            reply: 'Pick one.', target: 'crowded', interaction: 'choice', choices: ['Buy a ticket', 'Leave now']));
    final text = t.widget<Text>(find.descendant(of: find.byType(OutlinedButton), matching: find.byType(Text)).first);
    final spans = <TextSpan>[];
    text.textSpan!.visitChildren((x) {
      if (x is TextSpan && x.text != null) spans.add(x);
      return true;
    });
    expect(spans.firstWhere((x) => x.text == 'ticket').style?.fontWeight, FontWeight.w800);
  });

  // ---- talk-mission (owner, 2026-10-24) ----

  testWidgets('the mic is twice its old size, inside a ring to match', (t) async {
    await open(t);
    expect(t.getSize(find.byType(TalkRing)), const Size(talkRingSize, talkRingSize));
    expect(talkMicSize, greaterThanOrEqualTo(104));
    expect(t.takeException(), isNull);
  });

  testWidgets('while the voice is fetched a progress line fills on the bubble, the text stays; the voice starting ends it',
      (t) async {
    const line = 'Was the market crowded today?';
    await open(t, opening: line);
    expect(find.byKey(talkVoiceLoadingKey), findsOneWidget);
    double value() => t.widget<LinearProgressIndicator>(find.byKey(talkVoiceLoadingKey)).value!;
    final first = value();
    await t.pump(const Duration(milliseconds: 1500));
    expect(value(), greaterThan(first), reason: 'a real, filling progress line');
    expect(value(), lessThan(1));
    expect(
        find.descendant(of: find.byKey(talkBubbleKey(0)), matching: find.byKey(talkVoiceLoadingKey)), findsOneWidget);
    expect(find.text(line), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget);
    tts.progress!(0.1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(talkVoiceLoadingKey), findsNothing);
  });

  testWidgets('Play, Stop and Replay sit under the latest AI line', (t) async {
    await open(t, opening: 'Did you buy a ticket?');
    expect(find.byKey(talkPlayKey), findsOneWidget);
    expect(find.byKey(talkReplayKey), findsOneWidget);
    await t.tap(find.byTooltip('Stop'));
    await t.pump();
    await settle(t);
    expect(tts.stops, greaterThan(0));
    expect(find.byTooltip('Play'), findsOneWidget);
    final before = tts.spoken.length;
    await t.tap(find.byKey(talkReplayKey));
    await t.pump();
    await settle(t);
    expect(tts.spoken.length, before + 1);
    expect(tts.spoken.last, 'Did you buy a ticket?');
    expect(find.byTooltip('Stop'), findsOneWidget);
  });

  testWidgets('the mission card shows its picture, title, role and goal above the talk', (t) async {
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    await open(
      t,
      opening: 'Next! What is the problem?',
      mission: const TalkMission(
        title: 'The Lost Bag',
        role: 'You are a passenger.',
        goal: 'Get your bag back.',
        brief: 'Hidden facts.',
        words: ['crowded', 'ticket'],
        picture: 'A clerk.',
      ),
      pictures: FakeTalkPicture()..bytes = png,
    );
    expect(find.byKey(talkMissionKey), findsOneWidget);
    expect(find.text('The Lost Bag'), findsOneWidget);
    expect(find.text('You are a passenger.'), findsOneWidget);
    expect(find.text('Get your bag back.'), findsOneWidget);
    expect(find.text('Hidden facts.'), findsNothing, reason: 'the brief is never shown');
    expect(find.byKey(talkMissionPictureKey), findsOneWidget);
    expect(t.getTopLeft(find.byKey(talkMissionKey)).dy, lessThan(t.getTopLeft(find.byKey(talkBubbleKey(0))).dy));
    expect(find.descendant(of: find.byKey(talkStripKey), matching: find.text('wander')), findsNothing);
  });

  testWidgets('the word popup keeps a margin from the screen edges and points at the word', (t) async {
    await open(t, opening: 'Was it crowded?');
    await t.tapOnText(find.textRange.ofSubstring('crowded', descendentOf: find.byKey(talkBubbleKey(0))));
    await t.pump();
    await t.pump();
    final popup = t.getRect(find.byType(TalkWordPopup));
    expect(popup.left, greaterThanOrEqualTo(12));
    expect(popup.right, lessThanOrEqualTo(393 - 12));
    expect(popup.bottom, lessThanOrEqualTo(852));
  });

  testWidgets('tapping any other word of an AI line shows its translation (owner, 2026-10-24)', (t) async {
    await open(t, opening: 'Was the market crowded today?');
    translate.asked.clear();
    await t.tapOnText(find.textRange.ofSubstring('market', descendentOf: find.byKey(talkBubbleKey(0))));
    await t.pump();
    await settle(t);
    expect(translate.asked, ['market']);
    expect(find.byType(TalkLookupPopup), findsOneWidget);
    expect(find.text('т-market'), findsOneWidget);
    final popup = t.getRect(find.byType(TalkLookupPopup));
    expect(popup.left, greaterThanOrEqualTo(12));
    expect(popup.right, lessThanOrEqualTo(393 - 12));
    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(find.text('т-market'), findsNothing);

    // A practice word still opens its own popup with the saved translation.
    await t.tapOnText(find.textRange.ofSubstring('crowded', descendentOf: find.byKey(talkBubbleKey(0))));
    await t.pump();
    await t.pump();
    expect(find.text('t-crowded'), findsOneWidget);
    expect(find.byType(TalkLookupPopup), findsNothing);
  });
  testWidgets('Replay on a line already heard plays it again without the loading bar; every AI line has Play',
      (t) async {
    await open(t, opening: 'Did you buy a ticket?');
    tts.progress!(0.2);
    await t.pump();
    tts.finishSpeaking();
    await t.pump();
    await settle(t);
    await t.tap(find.byKey(talkReplayKey));
    await t.pump();
    expect(find.byKey(talkVoiceLoadingKey), findsNothing, reason: 'heard before: played from memory');
    expect(tts.spoken.last, 'Did you buy a ticket?');
    await t.tap(find.byTooltip('Stop'));
    await t.pump();
    await settle(t);
    api.answers.add(const TalkTurn(reply: 'Where to?', target: 'crowded'));
    await reply(t, 'Yes I did');
    expect(find.byKey(talkPlayKey), findsNWidgets(2), reason: 'one under each AI line');
  });
  testWidgets('a quick check opens in the chat once 5 words came up; a typed answer goes to it, not the AI',
      (t) async {
    await open(t,
        opening: 'The fog hides the shore, the tide rises, a gale hits the harbour.',
        words: const ['shore', 'tide', 'fog', 'gale', 'harbour']);
    await settle(t);
    expect(find.byKey(talkQuizCardKey), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.text('t-shore'), findsOneWidget, reason: 'Translate shows the translation');
    tts.finishSpeaking();
    await t.pump();
    await settle(t);
    expect(speech.untilPauseCalls, greaterThan(0), reason: 'a spoken step listens at once');
    final calls = api.calls.length;
    await t.enterText(find.byType(TextField), 'shore');
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    expect(api.calls.length, calls, reason: 'the answer never reaches the AI');
    expect(find.text('Right!'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('talk-quiz-next')));
    await t.pump();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.textContaining('_____'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('a long press dragged over several words translates them together (owner, 2026-10-24)', (t) async {
    const line = 'Was the market crowded today?';
    await open(t, opening: line);
    final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(talkBubbleKey(0)), matching: find.byType(RichText)).first);
    Offset centerOf(String part) {
      final start = line.indexOf(part);
      final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + part.length)).first;
      return paragraph.localToGlobal(box.toRect().center);
    }

    translate.asked.clear();
    final g = await t.startGesture(centerOf('market'));
    await t.pump(const Duration(milliseconds: 600)); // long press
    expect(find.byKey(talkSelectionKey), findsOneWidget, reason: 'the held word lights up');
    await g.moveTo(centerOf('today'));
    await t.pump();
    await g.up();
    await t.pump();
    await settle(t);
    expect(find.byKey(talkSelectionKey), findsNothing);
    expect(translate.asked, ['market crowded today']);
    expect(find.text('т-market crowded today'), findsOneWidget);
  });
  testWidgets('a glass tab shows the recognition mode; its panel switches it (owner, 2026-10-24)', (t) async {
    await open(t);
    expect(find.byKey(talkRecognitionTabKey), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    await t.tap(find.byKey(talkRecognitionTabKey));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byKey(talkRecognitionPanelKey), findsOneWidget);
    expect(find.text('Speech recognition'), findsOneWidget);
    await t.tap(find.text('On the phone only'));
    await t.pump();
    await settle(t);
    final container = ProviderScope.containerOf(t.element(find.byType(TalkScreen)));
    expect(container.read(speechOnDeviceProvider), isTrue);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Phone'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}


class _FakeTranslate extends GoogleTranslateService {
  final asked = <String>[];

  @override
  Future<WordTranslation> translateWord(String word, {required String to, String from = 'en'}) async {
    asked.add(word);
    return WordTranslation(result: TranslationResult(text: 'т-$word'), best: 'т-$word');
  }
}
