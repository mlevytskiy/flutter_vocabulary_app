import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../word_input/widgets/pronunciation_buttons.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/word_marks.dart';
import 'remember_or_not_notifier.dart';

class RememberOrNotScreen extends ConsumerStatefulWidget {
  const RememberOrNotScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  ConsumerState<RememberOrNotScreen> createState() => _RememberOrNotScreenState();
}

class _RememberOrNotScreenState extends ConsumerState<RememberOrNotScreen> {
  late final PronunciationService _pronunciation;

  @override
  void initState() {
    super.initState();
    _pronunciation = ref.read(pronunciationServiceProvider);
  }

  @override
  void dispose() {
    _pronunciation.stop();
    super.dispose();
  }

  Future<void> _speak(String word, Accent accent) async {
    try {
      await _pronunciation.speak(word, accent: accent);
    } on PronunciationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = rememberOrNotProvider(widget.collectionId, widget.groupId);
    // Anything still playing stops when the card changes (S-32).
    ref.listen(provider.select((a) => a.valueOrNull?.shown), (_, __) => _pronunciation.stop());
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Remember or not',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final card = s.card!;
        final style = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Card ${s.position} of ${s.total}'),
              const SizedBox(height: 16),
              if (!s.flipped) ...[
                InkWell(
                  key: const ValueKey('card-front'),
                  onTap: notifier.flip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(card.front, style: style.headlineSmall),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: notifier.flip, child: const Text('Flip')),
              ] else ...[
                Row(
                  children: [
                    Flexible(child: Text(card.word, style: style.headlineSmall)),
                    const SizedBox(width: 8),
                    PronunciationButtons(onSpeak: (accent) => _speak(card.word, accent)),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => notifier.rate(true),
                  child: Text(s.secondShowing ? 'Got it' : 'Remembered'),
                ),
                ElevatedButton(
                  onPressed: () => notifier.rate(false),
                  child: Text(s.secondShowing ? 'Still not' : 'Not yet'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
