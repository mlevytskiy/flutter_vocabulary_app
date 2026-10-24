import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/core/services/speech_input.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';

import 'learn_session_talk_test.dart' show FakeTalkApi;

/// A speech engine the test drives through the real [UntilPause]: [partial]
/// is the engine hearing words, [engineStopped] the engine ending a session
/// by itself (Android after ~2–3 s of silence, or a no-match error).
class EngineSpeech implements SpeechInput {
  EngineSpeech(this.log);

  final List<String> log;
  SpeechAvailability availability = SpeechAvailability.ready;
  int inits = 0;
  int untilPauseCalls = 0;
  int restarts = 0;
  bool listening = false;
  Duration? pause;
  UntilPause? run;

  void partial(String text) => run?.heard(text);
  void engineStopped() => run?.sessionEnded();

  @override
  Future<SpeechAvailability> init() async {
    inits++;
    return availability;
  }

  @override
  Future<void> listenUntilPause({
    required Duration pause,
    required void Function(String text) onPartial,
    required void Function(String text) onDone,
  }) async {
    untilPauseCalls++;
    this.pause = pause;
    listening = true;
    log.add('listen');
    final r = run = UntilPause(
      pause: pause,
      onPartial: onPartial,
      onDone: onDone,
      restart: () async => restarts++,
      stopEngine: () async => listening = false,
    );
    r.begin();
  }

  @override
  Future<void> stopListening() async {
    run?.cancel();
    listening = false;
  }

  @override
  Future<void> listen({required void Function(String text, bool isFinal) onText}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

/// Text to speech whose [speakAndWait] finishes when the test says so.
class HoldTts implements PronunciationService {
  HoldTts(this.log);

  final List<String> log;
  final spoken = <String>[];
  final voices = <VoiceId?>[];
  Completer<void>? _pending;
  int stops = 0;

  /// The last line's progress callback, for the karaoke (talk-screen-b).
  void Function(double progress)? progress;

  void finishSpeaking() => _pending?.complete();

  @override
  Future<void> speakAndWait(String text,
      {required Accent accent, VoiceId? voice, String? openAiVoice, void Function(double progress)? onProgress}) {
    spoken.add(text);
    voices.add(voice);
    progress = onProgress;
    log.add('speak');
    return (_pending = Completer<void>()).future;
  }

  @override
  Future<void> speak(String word, {required Accent accent}) async {}

  @override
  Future<List<TtsVoice>> englishVoices() async => const [];

  @override
  Future<void> stop() async {
    stops++;
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete();
  }
}

/// owner 2026-10-24 (AC-29): hands-free Talk — listens at once after the
/// AI's line was spoken, a pause sends, the reply is spoken, then it listens
/// again; the headset toggle switches back to tap/hold.
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
    dir = Directory.systemTemp.createTempSync('learn_session_talk_handsfree_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('UntilPause (silence detection of both engines)', () {
    late List<String> partials;
    late List<String> done;
    late int restarts;
    late int engineStops;
    late UntilPause run;

    void make({Duration pause = const Duration(seconds: 4)}) {
      partials = [];
      done = [];
      restarts = 0;
      engineStops = 0;
      run = UntilPause(
        pause: pause,
        onPartial: partials.add,
        onDone: done.add,
        restart: () async => restarts++,
        stopEngine: () async => engineStops++,
      )..begin();
    }

    testWidgets('4 s of silence after words ends with them', (t) async {
      make();
      run.heard('I took');
      await t.pump(const Duration(seconds: 2));
      run.heard('I took the bus');
      await t.pump(const Duration(milliseconds: 3900));
      expect(done, isEmpty);
      await t.pump(const Duration(milliseconds: 200));
      expect(done, ['I took the bus']);
      expect(engineStops, 1);
      expect(partials, ['I took', 'I took the bus']);
      run.heard('late words');
      expect(partials.length, 2);
    });

    testWidgets('an engine stop before the pause restarts and appends', (t) async {
      make();
      run.heard('the bus');
      await t.pump(const Duration(seconds: 2));
      run.sessionEnded();
      await t.pump(const Duration(milliseconds: 400));
      expect(restarts, 1);
      expect(done, isEmpty);
      run.heard('was');
      run.heard('was crowded');
      expect(partials.last, 'the bus was crowded');
      await t.pump(const Duration(seconds: 4));
      expect(done, ['the bus was crowded']);
    });

    testWidgets('a stop and an error of one session restart once', (t) async {
      make();
      run.heard('hello');
      run.sessionEnded();
      run.sessionEnded();
      await t.pump(const Duration(milliseconds: 400));
      expect(restarts, 1);
      run.heard('there');
      expect(partials.last, 'hello there');
      run.cancel();
    });

    testWidgets('nothing heard in 60 s ends with empty text', (t) async {
      make();
      await t.pump(const Duration(seconds: 59));
      expect(done, isEmpty);
      await t.pump(const Duration(seconds: 1));
      expect(done, ['']);
      expect(engineStops, 1);
    });

    testWidgets('cancel ends without onDone', (t) async {
      make();
      run.heard('hi');
      run.cancel();
      await t.pump(const Duration(seconds: 61));
      expect(done, isEmpty);
    });
  });

  late FakeTalkApi api;
  late EngineSpeech speech;
  late HoldTts tts;
  late List<String> log;
  late ProviderContainer container;

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump();
    }
  }

  Future<void> open(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    api = FakeTalkApi();
    log = [];
    speech = EngineSpeech(log);
    tts = HoldTts(log);
    late String id;
    await t.runAsync(() async {
      final c = await store.create(keep: true);
      c.words = [
        for (final (i, w) in ['crowded', 'ticket', 'bus'].indexed)
          WordPair(word: w, translation: 't-$w', rowId: 'r${i + 1}'),
      ];
      await store.put(c);
      id = c.collectionId;
    });
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
      speechInputProvider.overrideWithValue(speech),
      pronunciationServiceProvider.overrideWithValue(tts),
    ]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp(home: TalkScreen(collectionId: id, split: false))));
    await settle(t);
  }

  /// Lets the spoken line finish and the listening start.
  Future<void> finishSpeaking(WidgetTester t) async {
    tts.finishSpeaking();
    await t.pump();
    await t.pump();
  }

  final mic = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Tap to talk');
  String fieldText(WidgetTester t) => t.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('AC-29: on by default; the opening is spoken, listening starts only after it', (t) async {
    await open(t);
    expect(find.text('Tell me more.'), findsOneWidget);
    expect(find.byTooltip(talkHandsFreeOnTip), findsOneWidget);
    expect(tts.spoken, ['Tell me more.']);
    expect(speech.untilPauseCalls, 0);
    expect(find.text(talkSpeakingText), findsOneWidget);
    await finishSpeaking(t);
    expect(log, ['speak', 'listen']);
    expect(speech.untilPauseCalls, 1);
    expect(speech.pause, const Duration(seconds: 4));
    expect(find.text(talkListeningPauseText(4)), findsOneWidget);
    expect(talkListeningPauseText(4), 'Listening… pause 4 s to send');
  });

  testWidgets('AC-29: 4 s of silence sends the words; no listening while waiting or speaking', (t) async {
    await open(t);
    await finishSpeaking(t);
    final calls = api.calls.length;
    api.answers.add(const TalkTurn(reply: 'Was it late?', target: 'ticket'));
    speech.partial('I took the bus');
    await t.pump();
    expect(fieldText(t), 'I took the bus');
    await t.pump(const Duration(milliseconds: 3900));
    expect(api.calls.length, calls);
    await t.pump(const Duration(milliseconds: 200));
    expect(speech.listening, isFalse);
    await settle(t);
    expect(api.calls.length, calls + 1);
    expect(api.calls.last.history.last.text, 'I took the bus');
    expect(find.text('I took the bus'), findsOneWidget);
    expect(find.text('Was it late?'), findsOneWidget);
    expect(tts.spoken.last, 'Was it late?');
    expect(speech.untilPauseCalls, 1);
    expect(find.text(talkSpeakingText), findsOneWidget);
    await finishSpeaking(t);
    expect(speech.untilPauseCalls, 2);
    expect(log, ['speak', 'listen', 'speak', 'listen']);
  });

  testWidgets('AC-29: an early engine stop restarts listening and appends', (t) async {
    await open(t);
    await finishSpeaking(t);
    speech.partial('the bus');
    await t.pump(const Duration(seconds: 2));
    speech.engineStopped();
    await t.pump(const Duration(milliseconds: 400));
    expect(speech.restarts, 1);
    speech.partial('was crowded');
    await t.pump();
    expect(fieldText(t), 'the bus was crowded');
    await t.pump(const Duration(seconds: 4));
    await settle(t);
    expect(api.calls.last.history.last.text, 'the bus was crowded');
  });

  testWidgets("AC-29: nothing heard in 60 s stops with Didn't hear anything; the mic resumes", (t) async {
    await open(t);
    await finishSpeaking(t);
    final calls = api.calls.length;
    await t.pump(const Duration(seconds: 60));
    await t.pump();
    expect(speech.listening, isFalse);
    expect(find.text(talkNothingHeardText), findsOneWidget);
    expect(api.calls.length, calls);
    await t.pump(const Duration(seconds: 30));
    expect(speech.untilPauseCalls, 1);
    await t.tap(mic);
    await t.pump();
    await t.pump();
    expect(speech.untilPauseCalls, 2);
    expect(speech.listening, isTrue);
  });

  testWidgets('AC-29: the mic pauses and resumes the loop', (t) async {
    await open(t);
    await finishSpeaking(t);
    expect(speech.listening, isTrue);
    await t.tap(mic);
    await t.pump();
    expect(speech.listening, isFalse);
    expect(find.text(talkHandsFreeHintText(4)), findsOneWidget);
    await t.tap(mic);
    await t.pump();
    await t.pump();
    expect(speech.listening, isTrue);
    expect(speech.untilPauseCalls, 2);
  });

  testWidgets('AC-29: the headset toggle turns it off: tap mode as before, persisted', (t) async {
    await open(t);
    await finishSpeaking(t);
    await t.tap(find.byTooltip(talkHandsFreeOnTip));
    await t.pump();
    await settle(t);
    expect(speech.listening, isFalse);
    expect(find.byTooltip(talkHandsFreeOffTip), findsOneWidget);
    expect(find.text(talkMicHintText), findsOneWidget);
    expect(container.read(handsFreeProvider), isFalse);
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool('learn.handsFree'), isFalse);
  });

  testWidgets('AC-29: off in the prefs: nothing is spoken or heard until the mic', (t) async {
    await open(t, prefs: {'learn.handsFree': false});
    expect(tts.spoken, isEmpty);
    expect(speech.untilPauseCalls, 0);
    expect(find.text(talkMicHintText), findsOneWidget);
  });

  testWidgets('AC-29: a 2 s pause setting sends after 2 s', (t) async {
    await open(t, prefs: {'learn.pauseSeconds': 2});
    await finishSpeaking(t);
    expect(find.text(talkListeningPauseText(2)), findsOneWidget);
    final calls = api.calls.length;
    speech.partial('yes');
    await t.pump(const Duration(milliseconds: 2100));
    await settle(t);
    expect(api.calls.length, calls + 1);
  });

  testWidgets('AC-29: leaving the screen stops listening', (t) async {
    await open(t);
    await finishSpeaking(t);
    expect(speech.listening, isTrue);
    await t.pumpWidget(const SizedBox());
    expect(speech.listening, isFalse);
  });

  testWidgets('AC-29: leaving while speaking stops the voice', (t) async {
    await open(t);
    await t.pumpWidget(const SizedBox());
    expect(tts.stops, greaterThan(0));
    await t.pump();
    expect(speech.untilPauseCalls, 0);
  });

  group('the prefs', () {
    test('hands-free defaults on, pause 4 s', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(handsFreeProvider.notifier).loaded;
      await c.read(talkPauseProvider.notifier).loaded;
      expect(c.read(handsFreeProvider), isTrue);
      expect(c.read(talkPauseProvider), 4);
      expect(talkPauseChoices, [2, 3, 4, 6]);
    });

    for (final s in [2, 3, 4, 6]) {
      test('pause $s s persists', () async {
        SharedPreferences.setMockInitialValues({});
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await c.read(talkPauseProvider.notifier).set(s);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('learn.pauseSeconds'), s);
        final again = ProviderContainer();
        addTearDown(again.dispose);
        await again.read(talkPauseProvider.notifier).loaded;
        expect(again.read(talkPauseProvider), s);
      });
    }
  });
}
