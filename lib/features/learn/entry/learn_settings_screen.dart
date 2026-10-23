import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/speech_input.dart';
import '../../../router/routes.dart';
import '../exercises.dart';
import 'learn_presets.dart';

/// Said when a switch would leave a step with no exercise (AC-18).
const learnStepNeedsOneMessage = 'Each step needs at least one exercise';

const _stepTitles = {
  1: 'Step 1 · Meet',
  2: 'Step 2 · Practise',
  3: 'Step 3 · Use',
};

/// The Learn settings (learn-redesign SCR-05, ADR-0006, AC-17..19): the
/// preset, words per session, and every exercise of the plan with its switch
/// (the eleven session pages) and a "Try it" that opens it alone; under
/// Voice, the speech recognition engine of Talk with AI (AC-28).
class LearnSettingsScreen extends ConsumerWidget {
  const LearnSettingsScreen({super.key, this.collectionId});

  /// The collection "Try it" opens the exercise for, as on `LearnRoute`.
  final String? collectionId;

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, String id, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final done =
        await ref.read(learnSettingsProvider.notifier).setEnabled(id, on);
    if (!done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(learnStepNeedsOneMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(learnSettingsProvider);
    final notifier = ref.read(learnSettingsProvider.notifier);
    final engine = ref.watch(speechEngineProvider);
    final heading = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Preset', style: heading),
          ),
          RadioGroup<LearnPreset>(
            groupValue: settings.preset,
            onChanged: (p) {
              if (p != null) notifier.pickPreset(p);
            },
            child: Column(children: [
              for (final p in [
                LearnPreset.balanced,
                LearnPreset.quick,
                LearnPreset.deep,
                LearnPreset.custom,
              ])
                RadioListTile<LearnPreset>(
                  value: p,
                  title: Text(p.displayName),
                  subtitle: Text(p.subtitle),
                ),
            ]),
          ),
          ListTile(
            title: const Text('Words per session'),
            subtitle: const Text("Used when the words aren't split into groups"),
            trailing: DropdownButton<WordsPerSession>(
              value: settings.wordsPerSession,
              underline: const SizedBox.shrink(),
              onChanged: (w) {
                if (w != null) notifier.setWordsPerSession(w);
              },
              items: [
                for (final w in WordsPerSession.values)
                  DropdownMenuItem(
                    value: w,
                    child: Text(w.count?.toString() ?? 'All'),
                  ),
              ],
            ),
          ),
          for (final stage in _stepTitles.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(_stepTitles[stage]!, style: heading),
            ),
            for (final e in exercises.where((e) => e.stage == stage))
              ListTile(
                title: Text(e.name),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: () => LearnRoute(
                            collectionId: collectionId, exercise: e.id)
                        .push<void>(context),
                    child: const Text('Try it'),
                  ),
                  if (pageExerciseIds.contains(e.id))
                    Switch(
                      value: settings.enabled.contains(e.id),
                      onChanged: (on) => _toggle(context, ref, e.id, on),
                    ),
                ]),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Voice', style: heading),
          ),
          const ListTile(title: Text('Speech recognition')),
          RadioGroup<SpeechEngine>(
            groupValue: engine,
            onChanged: (e) {
              if (e != null) {
                ref.read(speechEngineProvider.notifier).set(e);
              }
            },
            child: Column(children: [
              for (final e in SpeechEngine.values)
                RadioListTile<SpeechEngine>(
                  value: e,
                  title: Text(e.label),
                  subtitle:
                      e == SpeechEngine.speechToText ? const Text('Default') : null,
                ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
