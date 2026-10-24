import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/openai_voice_service.dart';
import '../../../core/services/pronunciation_service.dart';

/// What Play sample says (learn-redesign AC-30).
const talkVoiceSample = "Hello! Let's practise your words.";

/// The iOS line on getting better voices (AC-30).
const iosBetterVoicesText = 'Better voices: iPhone Settings › Accessibility › Spoken Content › Voices › '
    'English — download an Enhanced or Premium voice.';

/// The line under the OpenAI choice (openai-voice, AC-31).
const openAiVoiceHelpText = 'Natural voice from OpenAI; needs internet. Falls back to the phone voice when offline.';

/// An OpenAI voice as the picker shows it: "coral" → "Coral".
String openAiVoiceLabel(String voice) => '${voice[0].toUpperCase()}${voice.substring(1)}';

/// One voice as the picker's radio value.
String voiceKey(VoiceId v) => '${v.locale}\t${v.name}';

/// Talk with AI's voice settings below Speech recognition in Learn settings
/// (owner, 2026-10-24): hands-free talk and its pause (AC-29), and the AI
/// voice: OpenAI's natural voices (the default, openai-voice AC-31) or the
/// installed English voices best first, each with Play sample (AC-30).
class TalkVoiceSection extends ConsumerWidget {
  const TalkVoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handsFree = ref.watch(handsFreeProvider);
    final pause = ref.watch(talkPauseProvider);
    final source = ref.watch(voiceSourceProvider);
    final openAiVoice = ref.watch(openAiVoiceProvider);
    final chosen = ref.watch(ttsVoiceProvider);
    final voices = ref.watch(englishVoicesProvider).value ?? const <TtsVoice>[];
    final selected = chosen ?? voices.firstOrNull?.id;
    final muted = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.headset_mic),
          title: const Text('Hands-free talk'),
          subtitle: const Text('Talk listens at once; a pause sends your reply'),
          value: handsFree,
          onChanged: (on) => ref.read(handsFreeProvider.notifier).set(on),
        ),
        ListTile(
          title: const Text('Pause to send'),
          trailing: DropdownButton<int>(
            value: pause,
            underline: const SizedBox.shrink(),
            onChanged: (s) {
              if (s != null) ref.read(talkPauseProvider.notifier).set(s);
            },
            items: [
              for (final s in talkPauseChoices) DropdownMenuItem(value: s, child: Text('$s s')),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: const Text('AI voice'),
          subtitle: const Text('The voice Talk with AI speaks with'),
          trailing: source == VoiceSource.phone
              ? TextButton(
                  onPressed: () => ref
                      .read(pronunciationServiceProvider)
                      .speakAndWait(talkVoiceSample, accent: Accent.us, voice: selected)
                      .catchError((Object _) {}),
                  child: const Text('Play sample'),
                )
              : null,
        ),
        RadioGroup<VoiceSource>(
          groupValue: source,
          onChanged: (s) {
            if (s != null) ref.read(voiceSourceProvider.notifier).set(s);
          },
          child: const Column(children: [
            RadioListTile<VoiceSource>(value: VoiceSource.openAi, title: Text('OpenAI (natural)')),
            RadioListTile<VoiceSource>(value: VoiceSource.phone, title: Text('Phone voice')),
          ]),
        ),
        if (source == VoiceSource.openAi) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(openAiVoiceHelpText, style: muted),
          ),
          RadioGroup<String>(
            groupValue: openAiVoice,
            onChanged: (v) {
              if (v != null) ref.read(openAiVoiceProvider.notifier).set(v);
            },
            child: Column(children: [
              for (final v in openAiVoices)
                RadioListTile<String>(
                  value: v,
                  title: Text(openAiVoiceLabel(v)),
                  // Each sample costs one of the day's speech calls.
                  secondary: TextButton(
                    onPressed: () => ref
                        .read(pronunciationServiceProvider)
                        .speakAndWait(talkVoiceSample, accent: Accent.us, openAiVoice: v)
                        .catchError((Object _) {}),
                    child: const Text('Play sample'),
                  ),
                ),
            ]),
          ),
        ],
        if (source == VoiceSource.phone && voices.isNotEmpty)
          RadioGroup<String>(
            groupValue: selected == null ? null : voiceKey(selected),
            onChanged: (key) {
              final v = voices.where((v) => voiceKey(v.id) == key).firstOrNull;
              if (v != null) ref.read(ttsVoiceProvider.notifier).set(v.id);
            },
            child: Column(children: [
              for (final v in voices)
                RadioListTile<String>(
                  value: voiceKey(v.id),
                  title: Text(v.name),
                  subtitle: Text('${v.quality.label} · ${v.locale}'),
                ),
            ]),
          ),
        if (source == VoiceSource.phone && defaultTargetPlatform == TargetPlatform.iOS)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(iosBetterVoicesText, style: muted),
          ),
      ],
    );
  }
}
