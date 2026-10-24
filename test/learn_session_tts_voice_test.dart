import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/talk_voice_section.dart';

class VoicesTts implements PronunciationService {
  VoicesTts(this.voices);

  final List<TtsVoice> voices;
  final said = <(String, VoiceId?)>[];

  @override
  Future<List<TtsVoice>> englishVoices() async => voices;

  @override
  Future<void> speakAndWait(String text,
      {required Accent accent, VoiceId? voice, String? openAiVoice, void Function(double progress)? onProgress}) async => said.add((text, voice));

  @override
  Future<void> speak(String word, {required Accent accent}) async {}

  @override
  Future<void> stop() async {}
}

/// owner 2026-10-24 (AC-29, AC-30): the best installed voice, the AI voice
/// picker with Play sample, and the hands-free rows in Learn settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rankEnglishVoices', () {
    test('iOS: premium > enhanced > default; English only; novelty voices left out', () {
      final ranked = rankEnglishVoices([
        {
          'name': 'Samantha',
          'locale': 'en-US',
          'quality': 'default',
          'identifier': 'com.apple.voice.compact.en-US.Samantha'
        },
        {
          'name': 'Zarvox',
          'locale': 'en-US',
          'quality': 'default',
          'identifier': 'com.apple.speech.synthesis.voice.Zarvox'
        },
        {'name': 'Ava', 'locale': 'en-US', 'quality': 'premium', 'identifier': 'com.apple.voice.premium.en-US.Ava'},
        {
          'name': 'Daniel',
          'locale': 'en-GB',
          'quality': 'enhanced',
          'identifier': 'com.apple.voice.enhanced.en-GB.Daniel'
        },
        {
          'name': 'Thomas',
          'locale': 'fr-FR',
          'quality': 'premium',
          'identifier': 'com.apple.voice.premium.fr-FR.Thomas'
        },
      ]);
      expect([for (final v in ranked) v.name], ['Ava', 'Daniel', 'Samantha']);
      expect([for (final v in ranked) v.quality.label], ['Premium', 'Enhanced', 'Standard']);
      expect(bestVoiceFor(ranked, 'en-US')!.name, 'Ava');
      expect(bestVoiceFor(ranked, 'en-GB')!.name, 'Daniel');
      expect(bestVoiceFor(ranked, 'en-AU'), isNull);
    });

    test('Android: very high > high > normal, offline first, not-installed left out', () {
      final ranked = rankEnglishVoices([
        {'name': 'en-us-x-iol-local', 'locale': 'en-US', 'quality': 'normal', 'network_required': '0', 'features': ''},
        {
          'name': 'en-us-x-tpf-network',
          'locale': 'en-US',
          'quality': 'very high',
          'network_required': '1',
          'features': ''
        },
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US', 'quality': 'high', 'network_required': '0', 'features': ''},
        {
          'name': 'en-gb-x-gba-local',
          'locale': 'en-GB',
          'quality': 'very high',
          'network_required': '0',
          'features': 'notInstalled'
        },
        {
          'name': 'de-de-x-deb-local',
          'locale': 'de-DE',
          'quality': 'very high',
          'network_required': '0',
          'features': ''
        },
      ]);
      expect([for (final v in ranked) v.name], ['en-us-x-sfg-local', 'en-us-x-iol-local', 'en-us-x-tpf-network']);
      expect(bestVoiceFor(ranked, 'en-US')!.name, 'en-us-x-sfg-local');
      expect(ranked.first.quality, VoiceQuality.enhanced);
      expect(ranked.last.quality, VoiceQuality.premium);
    });

    test('bad entries are skipped', () {
      expect(
          rankEnglishVoices([
            null,
            'x',
            {'locale': 'en-US'},
            {'name': 'A'}
          ]),
          isEmpty);
    });
  });

  group('AC-30: the AI voice picker', () {
    const voices = [
      TtsVoice(name: 'Ava', locale: 'en-US', quality: VoiceQuality.premium),
      TtsVoice(name: 'Daniel', locale: 'en-GB', quality: VoiceQuality.enhanced),
      TtsVoice(name: 'Samantha', locale: 'en-US', quality: VoiceQuality.standard),
    ];

    Future<(ProviderContainer, VoicesTts)> pump(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
      // The phone voices show with the Phone voice source (openai-voice, AC-31).
      SharedPreferences.setMockInitialValues({'learn.voiceSource': 'phone', ...prefs});
      t.view.physicalSize = const Size(800, 5000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final tts = VoicesTts(voices);
      final c = ProviderContainer(overrides: [pronunciationServiceProvider.overrideWithValue(tts)]);
      addTearDown(c.dispose);
      await t
          .pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: LearnSettingsScreen())));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      return (c, tts);
    }

    testWidgets('lists the voices sorted with quality labels; the best is picked by default', (t) async {
      await pump(t);
      expect(find.text('AI voice'), findsOneWidget);
      final ava = t.getTopLeft(find.text('Ava')).dy;
      final daniel = t.getTopLeft(find.text('Daniel')).dy;
      final samantha = t.getTopLeft(find.text('Samantha')).dy;
      expect(ava < daniel && daniel < samantha, isTrue);
      expect(find.text('Premium · en-US'), findsOneWidget);
      expect(find.text('Enhanced · en-GB'), findsOneWidget);
      expect(find.text('Standard · en-US'), findsOneWidget);
      expect(t.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, voiceKey(voices.first.id));
      expect(find.text(iosBetterVoicesText), findsNothing);
    });

    testWidgets('a picked voice persists and Play sample speaks with it', (t) async {
      final (c, tts) = await pump(t);
      await t.tap(find.text('Daniel'));
      await t.pumpAndSettle();
      expect(c.read(ttsVoiceProvider), (name: 'Daniel', locale: 'en-GB'));
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString('learn.ttsVoice'), isNotNull);
      await t.tap(find.text('Play sample'));
      await t.pump();
      expect(tts.said, [(talkVoiceSample, (name: 'Daniel', locale: 'en-GB'))]);
      expect(talkVoiceSample, "Hello! Let's practise your words.");

      final again = ProviderContainer();
      addTearDown(again.dispose);
      await t.runAsync(() => again.read(ttsVoiceProvider.notifier).loaded);
      expect(again.read(ttsVoiceProvider), (name: 'Daniel', locale: 'en-GB'));
    });

    testWidgets('Play sample with no choice speaks with the best voice', (t) async {
      final (_, tts) = await pump(t);
      await t.tap(find.text('Play sample'));
      await t.pump();
      expect(tts.said.single.$2, (name: 'Ava', locale: 'en-US'));
    });

    testWidgets('the iOS helper line shows on iOS only', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pump(t);
      expect(find.text(iosBetterVoicesText), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('AC-29: hands-free switch and pause dropdown persist', (t) async {
      final (c, _) = await pump(t);
      expect(find.text('Hands-free talk'), findsOneWidget);
      await t.tap(find.byType(DropdownButton<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('6 s').last);
      await t.pumpAndSettle();
      expect(c.read(talkPauseProvider), 6);
      await t.tap(find.widgetWithText(SwitchListTile, 'Hands-free talk'));
      await t.pumpAndSettle();
      expect(c.read(handsFreeProvider), isFalse);
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getInt('learn.pauseSeconds'), 6);
      expect(prefs.getBool('learn.handsFree'), isFalse);
    });
  });
}
