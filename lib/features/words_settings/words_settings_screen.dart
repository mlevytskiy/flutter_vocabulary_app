import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/offered_ai.dart';
import '../../core/models/story_run.dart';
import '../../core/providers.dart';

/// Every story run, newest first, re-emitted after each write.
final storyRunsProvider = StreamProvider.autoDispose<List<StoryRun>>((ref) async* {
  final store = await ref.watch(storyRunStoreProvider.future);
  yield* store.watchNewestFirst();
});

/// Holds the screen back until the saved choice has been read, so it never
/// flashes the defaults first.
final _choiceLoadedProvider = FutureProvider.autoDispose<void>(
    (ref) => ref.read(aiChoiceProvider.notifier).loaded);

/// What a finished step of one AI cost on average, from the learner's runs.
class AiAverage {
  const AiAverage(this.usd, this.runs);
  final double usd;
  final int runs;
}

/// The average price of the finished steps of [role] done by each AI (AC-12).
/// Kept separately per role: the same AI may write stories and prompts.
Map<String, AiAverage> averagesFor(List<StoryRun> runs, AiRole role) {
  final sums = <String, (double, int)>{};
  for (final run in runs) {
    for (final step in run.steps) {
      if (step.role != role.name || step.outcome != 'done' || step.priceUsd == null) {
        continue;
      }
      final (sum, n) = sums[step.modelId] ?? (0.0, 0);
      sums[step.modelId] = (sum + step.priceUsd!, n + 1);
    }
  }
  return {for (final e in sums.entries) e.key: AiAverage(e.value.$1 / e.value.$2, e.value.$2)};
}

/// "$0.30", "$0.015", "$0.0009": two decimals from ten cents up; below that
/// as many as needed (up to four), never fewer than two.
String formatUsd(double v) {
  if (v >= 0.1) return '\$${v.toStringAsFixed(2)}';
  var s = v.toStringAsFixed(v >= 0.001 ? 3 : 4);
  while (s.endsWith('0') && s.split('.').last.length > 2) {
    s = s.substring(0, s.length - 1);
  }
  return '\$$s';
}

/// The options of [role] from the cheapest to the most expensive (by the
/// estimate for a group of 15 words, or the price per picture). Equal or
/// unknown prices keep the offered order, unknown last.
List<OfferedAi> cheapestFirst(OfferedAiList offered, AiRole role) {
  double? price(OfferedAi ai) => role == AiRole.picture ? ai.usdPerPicture : ai.estimate15Usd;
  final list = offered.forRole(role);
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final pa = price(a.$2), pb = price(b.$2);
    if (pa == null || pb == null) {
      if (pa == null && pb == null) return a.$1.compareTo(b.$1);
      return pa == null ? 1 : -1;
    }
    final c = pa.compareTo(pb);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// The provider's list price, as a small line under an option.
String? listPriceLine(OfferedAi ai) {
  final approx = ai.approx ? '≈ ' : '';
  if (ai.isPicture) {
    if (ai.usdPerPicture == null) return null;
    return 'List price: $approx${formatUsd(ai.usdPerPicture!)} per picture';
  }
  if (ai.inputUsdPerMTok == null || ai.outputUsdPerMTok == null) return null;
  return 'List price: $approx${formatUsd(ai.inputUsdPerMTok!)} in · '
      '${formatUsd(ai.outputUsdPerMTok!)} out per 1M tokens';
}

/// Words settings (mnemonic-story, SCR-05): the AI for each of the three steps
/// of a story run, with prices (AC-12), and the way to the story runs (AC-14).
///
/// [onOpenStoryRuns] is what "Story runs" does; the route supplies it.
class WordsSettingsScreen extends ConsumerWidget {
  const WordsSettingsScreen({super.key, this.onOpenStoryRuns});

  final VoidCallback? onOpenStoryRuns;

  static const _titles = {
    AiRole.story: 'Story writer',
    AiRole.prompt: 'Picture prompt writer',
    AiRole.picture: 'Picture maker',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeredAsync = ref.watch(offeredAisProvider);
    final loaded = ref.watch(_choiceLoadedProvider);
    final stored = ref.watch(aiChoiceProvider);
    final runs = ref.watch(storyRunsProvider).valueOrNull ?? const <StoryRun>[];

    final Widget body;
    final offered = offeredAsync.valueOrNull;
    if (offered == null || !loaded.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final resolved = resolveAiChoice(stored, offered);
      body = ListView(
        children: [
          for (final role in AiRole.values) ...[
            _RoleSection(
              role: role,
              title: _titles[role]!,
              options: cheapestFirst(offered, role),
              selectedId: resolved.choice.of(role),
              unavailableName: resolved.unavailable[role],
              averages: role == AiRole.picture ? const {} : averagesFor(runs, role),
              onPick: (ai) => ref.read(aiChoiceProvider.notifier).set(role, ai),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('Story runs'),
            subtitle: const Text('Every story made, with its AIs, price and time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenStoryRuns,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Words settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: body,
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.role,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.unavailableName,
    required this.averages,
    required this.onPick,
  });

  final AiRole role;
  final String title;
  final List<OfferedAi> options;
  final String selectedId;
  final String? unavailableName;
  final Map<String, AiAverage> averages;
  final void Function(OfferedAi) onPick;

  String _label(OfferedAi ai) {
    if (ai.isPicture) {
      final price = ai.usdPerPicture;
      return price == null ? '' : '${ai.approx ? '≈ ' : ''}${formatUsd(price)} per picture';
    }
    final avg = averages[ai.id];
    if (avg != null) return '${formatUsd(avg.usd)} average · ${avg.runs} runs';
    final est = ai.estimate15Usd;
    return est == null ? '' : '≈ ${formatUsd(est)} (estimate)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(role == AiRole.picture ? Icons.image : Icons.auto_stories),
          title: Text(title),
        ),
        if (unavailableName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Text(
              '$unavailableName is no longer available',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        RadioGroup<String>(
          key: ValueKey('ai-group-${role.name}'),
          groupValue: selectedId,
          onChanged: (id) {
            final ai = options.where((o) => o.id == id).firstOrNull;
            if (ai != null) onPick(ai);
          },
          child: Column(
            children: [
              for (final ai in options)
                RadioListTile<String>(
                  key: ValueKey('ai-${role.name}-${ai.id}'),
                  value: ai.id,
                  title: Text(ai.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(ai)),
                      if (listPriceLine(ai) != null) Text(listPriceLine(ai)!, style: small),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
