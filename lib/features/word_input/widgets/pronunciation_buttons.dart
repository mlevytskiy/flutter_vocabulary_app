import 'package:flutter/material.dart';

import '../../../core/services/pronunciation_service.dart';

/// One flag+speaker button. Tapping it asks to hear the row's word in that
/// accent -- see [PronunciationButtons].
class _AccentButton extends StatelessWidget {
  final String flagEmoji;
  final String tooltip;
  final VoidCallback? onTap;

  const _AccentButton({
    required this.flagEmoji,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 26x26 to match the row's top strip and its close ("X") button
    // (word_row_item.dart) -- this sits in that same existing band, not a
    // new one, so it must fit inside it without clipping.
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        splashRadius: 14,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Text(flagEmoji, style: const TextStyle(fontSize: 13)),
            Positioned(
              bottom: -2,
              right: -3,
              child: Icon(Icons.volume_up, size: 9, color: Colors.purple[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// US and UK pronunciation triggers for a row's Word field
/// (docs/tasks/task-04-uk-us-pronunciation.md). Lives in the row's existing
/// top strip (`word_row_item.dart`, the 26px band the close/"X" button
/// already sits in), left of the "X" -- reusing that space rather than
/// growing the row or overlaying the field's own text. The caller only
/// includes this widget when it should be visible, so there is nothing to
/// hide here.
class PronunciationButtons extends StatelessWidget {
  final ValueChanged<Accent> onSpeak;

  const PronunciationButtons({
    super.key,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AccentButton(
          flagEmoji: '\u{1F1FA}\u{1F1F8}',
          tooltip: 'US pronunciation',
          onTap: () => onSpeak(Accent.us),
        ),
        _AccentButton(
          flagEmoji: '\u{1F1EC}\u{1F1E7}',
          tooltip: 'UK pronunciation',
          onTap: () => onSpeak(Accent.uk),
        ),
      ],
    );
  }
}
