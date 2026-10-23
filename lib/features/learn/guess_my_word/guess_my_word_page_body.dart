import 'package:flutter/material.dart';

import 'guess_my_word_notifier.dart';

/// One target of Guess my word (cut from [GuessMyWordScreen]'s round
/// builder), drawn by the exercise screen and by a learn page (learn-redesign
/// ADR-0003): the [header] line when there is one, the clues up to [level],
/// the grid and the target's outcome. [onNext] shows Next once the answer is
/// [revealed]; a learn page passes none (its verdict bar has Continue).
class GuessMyWordPageBody extends StatelessWidget {
  const GuessMyWordPageBody({
    super.key,
    this.header,
    required this.target,
    required this.level,
    required this.grid,
    required this.greyed,
    required this.points,
    required this.revealed,
    required this.onTap,
    this.onNext,
  });

  final String? header;
  final GuessWord target;
  final int level;
  final List<GuessWord> grid;
  final Set<String> greyed;
  final Map<String, int> points;
  final bool revealed;
  final ValueChanged<String> onTap;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final points = this.points[target.rowId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Text(header!),
          const SizedBox(height: 8),
        ],
        const Text('Tap the word the clues describe.'),
        const SizedBox(height: 16),
        for (var i = 0; i < level; i++) ...[
          Text('Clue ${i + 1}', style: style.labelMedium),
          const SizedBox(height: 2),
          Text(target.clues[i], key: ValueKey('guess-clue-${i + 1}'), style: style.bodyLarge),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        _Grid(
          words: grid,
          targetId: target.rowId,
          greyed: greyed,
          points: this.points,
          onTap: onTap,
        ),
        const SizedBox(height: 16),
        if (revealed) ...[
          Text('The word was “${target.word}”.'),
          if (onNext != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onNext, child: const Text('Next')),
          ],
        ] else if (points != null)
          Text('Right: ${points == 1 ? '1 point' : '$points points'}'),
      ],
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
