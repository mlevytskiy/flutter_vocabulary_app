import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/speech_input.dart';

/// The speech recognition engine of Talk with AI (learn-redesign AC-28,
/// ADR-0009 amendment): speech_to_text (default) or speech_to_text_pro.
/// Shown at the top of Learn settings and in the Words screen's Settings
/// (owner, 2026-10-24).
class SpeechEngineSection extends ConsumerWidget {
  const SpeechEngineSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(speechEngineProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.mic_none),
          title: Text('Speech recognition'),
          subtitle: Text('How Talk with AI turns your voice into text'),
        ),
        RadioGroup<SpeechEngine>(
          groupValue: engine,
          onChanged: (e) {
            if (e != null) {
              ref.read(speechEngineProvider.notifier).set(e);
            }
          },
          child: Column(children: [
            for (final e in SpeechEngine.offered)
              RadioListTile<SpeechEngine>(
                value: e,
                title: Text(e.label),
                subtitle: e == SpeechEngine.speechToText
                    ? const Text('Default')
                    : null,
              ),
          ]),
        ),
      ],
    );
  }
}
