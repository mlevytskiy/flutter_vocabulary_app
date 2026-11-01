import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../words/widgets/pronunciation_buttons.dart';
import '../kit/word_marks.dart';
import '../session/exercise_page.dart';
import '../session/flip_card.dart';
import 'remember_or_not_pages.dart';

/// One flash card (learn-remember-or-not): the masked front with Flip, then
/// the word with its speakers, translation and example and the two rating
/// buttons. Drawn by the old screen and by a session page (learn-redesign
/// ADR-0003); [onRate] gets true for the "remembered" button.
class RememberOrNotPageBody extends StatelessWidget {
  const RememberOrNotPageBody({
    super.key,
    required this.card,
    required this.flipped,
    required this.onFlip,
    required this.onSpeak,
    required this.rememberedLabel,
    required this.notLabel,
    required this.onRate,
  });

  final FlashCard card;
  final bool flipped;
  final VoidCallback onFlip;
  final ValueChanged<Accent> onSpeak;
  final String rememberedLabel;
  final String notLabel;
  final ValueChanged<bool> onRate;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    // The word turns over in 3D (learn-flow-cards, owner 2026-11-01).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FlipCard(
          flipped: flipped,
          onTap: flipped ? null : onFlip,
          front: Padding(
            key: const ValueKey('card-front'),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Text(card.front, style: style.headlineSmall),
          ),
          back: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(card.word, style: style.headlineSmall)),
                    const SizedBox(width: 8),
                    PronunciationButtons(onSpeak: onSpeak),
                  ],
                ),
                if (card.translation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(card.translation, style: style.titleMedium),
                ],
                if (card.example != null) ...[
                  const SizedBox(height: 16),
                  Text.rich(
                    key: const ValueKey('example'),
                    TextSpan(children: boldWord(card.example!, card.word)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!flipped)
          ElevatedButton(onPressed: onFlip, child: const Text('Flip'))
        else ...[
          ElevatedButton(
            onPressed: () => onRate(true),
            child: Text(rememberedLabel),
          ),
          ElevatedButton(
            onPressed: () => onRate(false),
            child: Text(notLabel),
          ),
        ],
      ],
    );
  }
}

/// [RememberOrNotPageBody] in a learning session (learn-redesign screens.md
/// SCR-03): "I knew it" / "I didn't" replace Check and report the page through
/// [answer] as done, "I didn't" as a miss (AC-09). No card is put back: the
/// session's ladder brings a missed word again.
class RememberOrNotSessionBody extends ConsumerStatefulWidget {
  const RememberOrNotSessionBody({super.key, required this.card, required this.answer});

  final FlashCard card;
  final PageAnswer answer;

  @override
  ConsumerState<RememberOrNotSessionBody> createState() => _RememberOrNotSessionBodyState();
}

class _RememberOrNotSessionBodyState extends ConsumerState<RememberOrNotSessionBody> {
  PronunciationService? _pronunciation;
  bool _flipped = false;
  bool _rated = false;

  @override
  void dispose() {
    // Anything still playing stops when the page changes (S-32).
    _pronunciation?.stop();
    super.dispose();
  }

  Future<void> _speak(String word, Accent accent) async {
    final PronunciationService pronunciation = _pronunciation ?? ref.read(pronunciationServiceProvider);
    _pronunciation = pronunciation;
    try {
      await pronunciation.speak(word, accent: accent);
    } on PronunciationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _rate(bool knew) {
    if (_rated) return;
    _rated = true;
    widget.answer.done({widget.card.rowId: knew});
  }

  @override
  Widget build(BuildContext context) => RememberOrNotPageBody(
        card: widget.card,
        flipped: _flipped,
        onFlip: () => setState(() => _flipped = true),
        onSpeak: (accent) => _speak(widget.card.word, accent),
        rememberedLabel: 'I knew it',
        notLabel: "I didn't",
        onRate: _rate,
      );
}
