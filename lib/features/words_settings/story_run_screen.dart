import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/story_run.dart';
import '../../core/providers.dart';
import 'story_runs_screen.dart';
import 'words_settings_screen.dart';

/// One story run in full (mnemonic-story, SCR-07, AC-14, AC-15): each step's AI,
/// result, price and time, failed attempts included. Reads only what the app
/// stored.
class StoryRunScreen extends ConsumerWidget {
  const StoryRunScreen({super.key, required this.runId});

  final String runId;

  static const _titles = {
    'story': 'Story writer',
    'prompt': 'Picture prompt writer',
    'picture': 'Picture maker',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(storyRunsProvider);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final runs = runsAsync.valueOrNull;
    final run = runs?.where((r) => r.runId == runId).firstOrNull;

    final Widget body;
    if (runs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (run == null) {
      body = const Center(child: Text('This story run is not on this phone'));
    } else {
      final steps = [...run.steps]..sort((a, b) {
          final r = _order(a.role).compareTo(_order(b.role));
          return r != 0 ? r : a.attempt.compareTo(b.attempt);
        });
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(run.groupName, style: theme.textTheme.titleLarge),
          Text('${formatRunDate(run.startedAt)} · ${run.words.length} words', style: small),
          const SizedBox(height: 4),
          Text(runStatusLine(run)),
          if (stepsTotals(run.steps).isNotEmpty) Text('Total: ${stepsTotals(run.steps)}'),
          const Divider(height: 24),
          for (final step in steps) _StepCard(runId: run.runId, step: step),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story run'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: body,
    );
  }

  static int _order(String role) => const ['story', 'prompt', 'picture'].indexOf(role);
}

class _StepCard extends ConsumerWidget {
  const _StepCard({required this.runId, required this.step});

  final String runId;
  final StoryStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final name = step.modelName.isNotEmpty ? step.modelName : step.modelId;
    final totals = stepsTotals([step]);
    return Padding(
      key: ValueKey('step-${step.role}-${step.attempt}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${StoryRunScreen._titles[step.role] ?? step.role}: $name',
              style: theme.textTheme.titleSmall),
          if (step.outcome == 'failed')
            Text('Failed', style: TextStyle(color: theme.colorScheme.error))
          else if (step.outcome == 'running')
            Text('Still running', style: small),
          if (totals.isNotEmpty) Text(totals, style: small),
          if (step.text != null && step.text!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(step.text!, style: theme.textTheme.bodyMedium),
          ],
          if (step.missedWords.isNotEmpty)
            Text('Left out: ${step.missedWords.join(', ')}',
                style: TextStyle(color: theme.colorScheme.error)),
          if (step.role == 'picture' && step.picturePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FutureBuilder<Uint8List?>(
                future: ref.read(storyPictureStoreProvider).read(runId, step.attempt),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  return bytes == null
                      ? const SizedBox.shrink()
                      : Image.memory(bytes, fit: BoxFit.contain, width: double.infinity);
                },
              ),
            ),
        ],
      ),
    );
  }
}
