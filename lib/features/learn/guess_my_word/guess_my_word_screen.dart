import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'guess_my_word_notifier.dart';

/// Guess my word for one word group (learn-guess-my-word): the clues so far,
/// a grid of the round's words and the outcome of the current target, inside
/// the shared frame (S-30, S-52). State lives in the notifier.
class GuessMyWordScreen extends ConsumerWidget {
  const GuessMyWordScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = guessMyWordProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Guess my word',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final target = s.target!;
        final style = Theme.of(context).textTheme;
        final points = s.points[target.rowId];
        final counter = 'Word ${s.targetIndex + 1} of ${s.targets.length}';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(round.count >= 2 ? 'Round ${round.index + 1} of ${round.count} · $counter' : counter),
              const SizedBox(height: 8),
              const Text('Tap the word the clues describe.'),
              const SizedBox(height: 16),
              for (var i = 0; i < s.level; i++) ...[
                Text('Clue ${i + 1}', style: style.labelMedium),
                const SizedBox(height: 2),
                Text(target.clues[i], key: ValueKey('guess-clue-${i + 1}'), style: style.bodyLarge),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              _Grid(
                words: s.grid,
                targetId: target.rowId,
                greyed: s.greyed,
                points: s.points,
                onTap: notifier.tap,
              ),
              const SizedBox(height: 16),
              if (s.revealed) ...[
                Text('The word was “${target.word}”.'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
              ] else if (points != null)
                Text('Right: ${points == 1 ? '1 point' : '$points points'}'),
            ],
          ),
        );
      },
    );
  }
}

/// The round's words, three per row. A found word shows its points, the
/// answer of a missed target is marked, a greyed word is dimmed.
class _Grid extends StatelessWidget {
  const _Grid({required this.words, required this.targetId, required this.greyed, required this.points, required this.onTap});

  final List<GuessWord> words;
  final String targetId;
  final Set<String> greyed;
  final Map<String, int> points;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < words.length; i += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + 3; j++) ...[
                    if (j > i) const SizedBox(width: 8),
                    Expanded(
                      child: j < words.length
                          ? _Tile(
                              word: words[j],
                              greyed: greyed.contains(words[j].rowId),
                              points: points[words[j].rowId],
                              onTap: () => onTap(words[j].rowId),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({required this.word, required this.greyed, required this.points, required this.onTap});

  final GuessWord word;
  final bool greyed;

  /// Null while the word is still in play; 0 = shown as the answer.
  final int? points;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = widget.points;
    final found = points != null && points > 0;
    final missed = points == 0;
    final radius = BorderRadius.circular(8);
    final textColor = widget.greyed
        ? scheme.onSurface.withValues(alpha: 0.38)
        : found
            ? scheme.onSurfaceVariant
            : missed
                ? scheme.onErrorContainer
                : scheme.onSurface;
    return Tooltip(
      key: _tooltip,
      message: widget.word.translation,
      triggerMode: TooltipTriggerMode.manual,
      child: Material(
        key: ValueKey('guess-word-${widget.word.rowId}'),
        color: widget.greyed
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : found
                ? scheme.surfaceContainerHighest
                : missed
                    ? scheme.errorContainer
                    : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: missed ? scheme.error : scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          onLongPress: () => _tooltip.currentState?.ensureTooltipVisible(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (found) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: scheme.secondary,
                    foregroundColor: scheme.onSecondary,
                    child: Text('$points', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.word.word,
                    style: TextStyle(color: textColor, decoration: widget.greyed ? TextDecoration.lineThrough : null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
