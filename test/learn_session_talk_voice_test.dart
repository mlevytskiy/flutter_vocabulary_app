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
import 'package:flutter_vocabulary_app/features/learn/entry/learn_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';

import 'learn_session_talk_test.dart' show FakeTalkApi;

/// A speech input the test drives: [heard] pushes words, [stop] delivers
/// [finalText] as the final result.
class FakeSpeech implements SpeechInput {
  SpeechAvailability availability = SpeechAvailability.ready;
  int inits = 0;
  bool listening = false;
  String finalText = '';
  void Function(String text, bool isFinal)? _onText;

  void heard(String text) => _onText?.call(text, false);

  @override
  Future<SpeechAvailability> init() async {
    inits++;
    return availability;
  }

  @override
  Future<void> listen({required void Function(String text, bool isFinal) onText}) async {
    _onText = onText;
    listening = true;
  }

  @override
  Future<void> stop() async {
    listening = false;
    if (finalText.isNotEmpty) _onText?.call(finalText, true);
  }

  @override
  Future<void> cancel() async => listening = false;
}

class FakePronunciation implements PronunciationService {
  final spoken = <String>[];

  @override
  Future<void> speak(String word, {required Accent accent}) async => spoken.add(word);

  @override
  Future<void> stop() async {}
}

/// learn-redesign T19 (AC-25, AC-26, AC-28; ADR-0009): hold-to-talk in Talk
/// with AI over a fake speech input, and the engine choice in Learn settings.
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
    dir = Directory.systemTemp.createTempSync('learn_session_talk_voice_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  late FakeTalkApi api;
  late FakeSpeech speech;
  late FakePronunciation tts;

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump();
    }
  }

  Future<void> open(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    api = FakeTalkApi();
    speech = FakeSpeech();
    tts = FakePronunciation();
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
    final container = ProviderContainer(overrides: [
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

  final mic = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Tap to talk');
  String fieldText(WidgetTester t) => t.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('AC-25: hold shows Listening… and the words, release sends the final text', (t) async {
    await open(t);
    expect(find.text('Tell me more.'), findsOneWidget);
    expect(mic, findsOneWidget);
    final hold = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(speech.inits, 1);
    expect(speech.listening, isTrue);
    expect(find.text(talkListeningHoldText), findsOneWidget);
    speech.heard('the bus');
    await t.pump();
    expect(fieldText(t), 'the bus');
    speech.finalText = 'The bus was crowded';
    await hold.up();
    await t.pump();
    await settle(t);
    expect(speech.listening, isFalse);
    expect(find.text(talkListeningHoldText), findsNothing);
    expect(find.text('The bus was crowded'), findsOneWidget);
    expect(find.text('crowded ✓'), findsOneWidget);
    expect(fieldText(t), isEmpty);
    expect(api.calls.last.history.last.text, 'The bus was crowded');
  });

  testWidgets('a tap starts listening, the next tap sends; the hint says so', (t) async {
    await open(t);
    expect(find.text(talkMicHintText), findsOneWidget);
    final first = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await first.up();
    await t.pump();
    expect(speech.listening, isTrue);
    expect(find.text(talkListeningTapText), findsOneWidget);
    speech.finalText = 'I took the bus';
    final second = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await second.up();
    await t.pump();
    await settle(t);
    expect(speech.listening, isFalse);
    expect(find.text('I took the bus'), findsOneWidget);
    expect(api.calls.last.history.last.text, 'I took the bus');
  });

  testWidgets('AC-25: the AI reply is read aloud only after the mic was used', (t) async {
    await open(t);
    expect(tts.spoken, isEmpty);
    api.answers.add(const TalkTurn(reply: 'Was it late?', target: 'ticket'));
    await t.enterText(find.byType(TextField), 'typed reply');
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    await settle(t);
    expect(find.text('Was it late?'), findsOneWidget);
    expect(tts.spoken, isEmpty);

    api.answers.add(const TalkTurn(reply: 'Did you buy a ticket?', target: 'ticket'));
    final hold = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    speech.finalText = 'yes it was';
    await hold.up();
    await t.pump();
    await settle(t);
    expect(find.text('Did you buy a ticket?'), findsOneWidget);
    expect(tts.spoken, ['Did you buy a ticket?']);
  });

  testWidgets('AC-25: an empty hold sends nothing', (t) async {
    await open(t);
    final calls = api.calls.length;
    final hold = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await hold.up();
    await t.pump();
    await settle(t);
    expect(api.calls.length, calls);
  });

  testWidgets('AC-26: refused permission says how to allow it; typing still works', (t) async {
    await open(t);
    speech.availability = SpeechAvailability.permissionDenied;
    final hold = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await hold.up();
    await t.pump();
    expect(speech.listening, isFalse);
    expect(find.text(talkVoiceRefusedMessage), findsOneWidget);
    expect(talkVoiceRefusedMessage, 'Allow the microphone and speech recognition in Settings to talk');
    await t.enterText(find.byType(TextField), 'typed instead');
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    await settle(t);
    expect(find.text('typed instead'), findsOneWidget);
  });

  testWidgets('AC-28: an unavailable engine hides the mic and shows the message', (t) async {
    await open(t);
    speech.availability = SpeechAvailability.unavailable;
    final hold = await t.startGesture(t.getCenter(mic));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await hold.up();
    await t.pump();
    expect(mic, findsNothing);
    expect(find.text(talkVoiceRefusedMessage), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  group('AC-28: the engine choice', () {
    test('defaults to speech_to_text', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(speechEngineProvider.notifier).loaded;
      expect(c.read(speechEngineProvider), SpeechEngine.speechToText);
      expect(c.read(speechInputProvider), isA<SpeechToTextInput>());
    });

    test('a stored choice is read back', () async {
      SharedPreferences.setMockInitialValues({'learn.speechEngine': 'speechToTextPro'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(speechEngineProvider.notifier).loaded;
      expect(c.read(speechEngineProvider), SpeechEngine.speechToTextPro);
      expect(c.read(speechInputProvider), isA<SpeechToTextProInput>());
    });

    testWidgets('Learn settings picks the engine, persists it and switches the input', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(800, 4000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await t.runAsync(() => c.read(speechEngineProvider.notifier).loaded);
      await t.pumpWidget(
          UncontrolledProviderScope(container: c, child: const MaterialApp(home: LearnSettingsScreen())));
      await t.pumpAndSettle();
      expect(find.text('Speech recognition'), findsOneWidget);
      expect(find.text('speech_to_text'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(
          t.widget<RadioGroup<SpeechEngine>>(find.byType(RadioGroup<SpeechEngine>)).groupValue,
          SpeechEngine.speechToText);
      await t.tap(find.text('speech_to_text_pro'));
      await t.pumpAndSettle();
      expect(c.read(speechEngineProvider), SpeechEngine.speechToTextPro);
      expect(c.read(speechInputProvider), isA<SpeechToTextProInput>());
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString('learn.speechEngine'), 'speechToTextPro');
    });
  });
}
