import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/openai_voice_service.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/talk_voice_section.dart';

class SampleTts implements PronunciationService {
  final said = <(String, String?)>[];

  @override
  Future<List<TtsVoice>> englishVoices() async =>
      const [TtsVoice(name: 'Ava', locale: 'en-US', quality: VoiceQuality.premium)];

  @override
  Future<void> speakAndWait(String text,
          {required Accent accent,
          VoiceId? voice,
          String? openAiVoice,
          void Function(double progress)? onProgress}) async =>
      said.add((text, openAiVoice));

  @override
  Future<void> speak(String word, {required Accent accent}) async {}

  @override
  Future<void> stop() async {}
}

/// openai-voice (owner, 2026-10-24; AC-31): "AI voice: OpenAI (natural) /
/// Phone voice" and the OpenAI voice picker in Learn settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SampleTts)> pump(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    t.view.physicalSize = const Size(800, 5000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final tts = SampleTts();
    final c = ProviderContainer(overrides: [pronunciationServiceProvider.overrideWithValue(tts)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: LearnSettingsScreen())));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    return (c, tts);
  }

  testWidgets('OpenAI is the default: its voices are listed, coral first and picked; the phone list is hidden',
      (t) async {
    final (c, _) = await pump(t);
    expect(c.read(voiceSourceProvider), VoiceSource.openAi);
    expect(c.read(openAiVoiceProvider), 'coral');
    expect(find.text('OpenAI (natural)'), findsOneWidget);
    expect(find.text('Phone voice'), findsOneWidget);
    expect(find.text(openAiVoiceHelpText), findsOneWidget);
    expect(
        openAiVoiceHelpText, 'Natural voice from OpenAI; needs internet. Falls back to the phone voice when offline.');
    expect(openAiVoices.first, 'coral');
    for (final v in openAiVoices) {
      expect(find.text(openAiVoiceLabel(v)), findsOneWidget, reason: v);
    }
    expect(t.getTopLeft(find.text('Coral')).dy < t.getTopLeft(find.text('Nova')).dy, isTrue);
    expect(t.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'coral');
    expect(find.text('Ava'), findsNothing);
    expect(find.text('Play sample'), findsNWidgets(openAiVoices.length));
  });

  testWidgets('a picked OpenAI voice persists; its Play sample synthesizes the sample with it', (t) async {
    final (c, tts) = await pump(t);
    await t.tap(find.text('Sage'));
    await t.pumpAndSettle();
    expect(c.read(openAiVoiceProvider), 'sage');
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString('learn.openAiVoice'), 'sage');
    await t.tap(
        find.descendant(of: find.widgetWithText(RadioListTile<String>, 'Onyx'), matching: find.text('Play sample')));
    await t.pump();
    expect(tts.said, [(talkVoiceSample, 'onyx')]);

    final again = ProviderContainer();
    addTearDown(again.dispose);
    await t.runAsync(() => again.read(openAiVoiceProvider.notifier).loaded);
    expect(again.read(openAiVoiceProvider), 'sage');
  });

  testWidgets('Phone voice persists and shows the phone voices instead', (t) async {
    final (c, _) = await pump(t);
    await t.tap(find.text('Phone voice'));
    await t.pumpAndSettle();
    expect(c.read(voiceSourceProvider), VoiceSource.phone);
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString('learn.voiceSource'), 'phone');
    expect(find.text('Ava'), findsOneWidget);
    expect(find.text('Coral'), findsNothing);
    expect(find.text(openAiVoiceHelpText), findsNothing);

    final again = ProviderContainer();
    addTearDown(again.dispose);
    await t.runAsync(() => again.read(voiceSourceProvider.notifier).loaded);
    expect(again.read(voiceSourceProvider), VoiceSource.phone);
  });

  testWidgets('a stored unknown voice reads as coral', (t) async {
    final (c, _) = await pump(t, prefs: {'learn.openAiVoice': 'robot'});
    expect(c.read(openAiVoiceProvider), 'coral');
  });
}
