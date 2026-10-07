import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/story_run.dart';
import 'words_settings_screen.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "7 Oct 2026".
String formatRunDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "4 s", "2 min 5 s", "2 min"; under a second "<1 s".
String formatRunTime(int ms) {
  final s = (ms / 1000).round();
  if (s < 1) return '<1 s';
  if (s < 60) return '$s s';
  final m = s ~/ 60, r = s % 60;
  return r == 0 ? '$m min' : '$m min $r s';
}

/// A step's price with "≈" when estimated (AC-14).
String formatStepPrice(StoryStep s) =>
    s.priceUsd == null ? '' : '${s.priceEstimated ? '≈ ' : ''}${formatUsd(s.priceUsd!)}';

/// "$0.032 · 15 s": the sum of the steps' prices, "≈" if any is estimated, and
/// the sum of their times (so a closed app does not count). Empty parts are
/// left out.
String stepsTotals(Iterable<StoryStep> steps) {
  final priced = steps.where((s) => s.priceUsd != null);
  final price = priced.isEmpty
      ? ''
      : '${priced.any((s) => s.priceEstimated) ? '≈ ' : ''}'
          '${formatUsd(priced.fold<double>(0, (a, s) => a + s.priceUsd!))}';
  final timed = steps.where((s) => s.ms != null);
  final time = timed.isEmpty ? '' : formatRunTime(timed.fold<int>(0, (a, s) => a + s.ms!));
  return [price, time].where((p) => p.isNotEmpty).join(' · ');
}

/// True for a run that never reached the Worker: failed with no steps.
bool runNeverStarted(StoryRun run) => run.outcome == 'failed' && run.steps.isEmpty;

StoryStep? lastStep(StoryRun run, String role) =>
    run.steps.where((s) => s.role == role).lastOrNull;

/// "Finished", "Still running" or where the run stopped (AC-14, AC-15).
String runStatusLine(StoryRun run) {
  if (runNeverStarted(run)) return 'Not started — no cost';
  if (run.outcome == 'running') return 'Still running';
  const stops = {
    'story': 'Stopped at the story',
    'prompt': 'Stopped at the picture prompt',
    'picture': 'Stopped at the picture',
  };
  for (final role in const ['story', 'prompt', 'picture']) {
    if (lastStep(run, role)?.outcome != 'done') return stops[role]!;
  }
  return 'Finished';
}

/// The AIs of a run in step order, by name where a step recorded one.
String runAisLine(StoryRun run) {
  const roles = ['story', 'prompt', 'picture'];
  return [
    for (var i = 0; i < roles.length; i++)
      () {
        final name = lastStep(run, roles[i])?.modelName ?? '';
        if (name.isNotEmpty) return name;
        return i < run.models.length ? run.models[i] : '';
      }()
  ].where((n) => n.isNotEmpty).join(' · ');
}

/// Every story run, newest first (mnemonic-story, SCR-06, AC-14, AC-15).
/// Runs that stopped or were replaced stay listed; runs that never started are
/// listed too, labelled "Not started — no cost".
///
/// [onOpenRun] is what tapping a run does; the route supplies it.
class StoryRunsScreen extends ConsumerWidget {
  const StoryRunsScreen({super.key, required this.onOpenRun});

  final void Function(String runId) onOpenRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(storyRunsProvider);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    final Widget body;
    final runs = runsAsync.valueOrNull;
    if (runs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (runs.isEmpty) {
      body = const Center(child: Text('No story runs yet'));
    } else {
      final sorted = [...runs]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      body = ListView(
        children: [
          for (final run in sorted)
            ListTile(
              key: ValueKey('run-${run.runId}'),
              isThreeLine: true,
              title: Text(run.groupName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatRunDate(run.startedAt), style: small),
                  if (runAisLine(run).isNotEmpty) Text(runAisLine(run)),
                  if (stepsTotals(run.steps).isNotEmpty) Text(stepsTotals(run.steps)),
                  Text(runStatusLine(run),
                      style: run.outcome == 'failed' && !runNeverStarted(run)
                          ? TextStyle(color: theme.colorScheme.error)
                          : small),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenRun(run.runId),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story runs'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: body,
    );
  }
}
