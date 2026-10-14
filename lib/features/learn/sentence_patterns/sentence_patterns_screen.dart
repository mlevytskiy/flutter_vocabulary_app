import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../word_input/widgets/pronunciation_buttons.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import 'sentence_patterns_notifier.dart';

class SentencePatternsScreen extends ConsumerStatefulWidget {
  const SentencePatternsScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  ConsumerState<SentencePatternsScreen> createState() => _SentencePatternsScreenState();
}

class _SentencePatternsScreenState extends ConsumerState<SentencePatternsScreen> {
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

  Future<void> _speak(String sentence, Accent accent) async {
    try {
      await _pronunciation.speak(sentence, accent: accent);
    } on PronunciationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = sentencePatternsProvider(widget.sessionId, widget.groupId);
    // Anything still playing stops when the card changes (S-32).
    ref.listen(provider.select((a) => a.valueOrNull?.card), (_, __) => _pronunciation.stop());
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Sentence patterns',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final card = s.card!;
        final result = s.result;
        final style = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word ${s.index + 1} of ${s.cards.length}'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      key: const ValueKey('pattern-sentence'),
                      TextSpan(children: boldWord(card.sentence, card.word)),
                      style: style.titleMedium,
                    ),
                  ),
                  PronunciationButtons(onSpeak: (accent) => _speak(card.sentence, accent)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Pattern: ${card.pattern}'),
              const SizedBox(height: 4),
              Text('Use it to: ${card.usage}'),
              const SizedBox(height: 8),
              Text(card.translation, style: style.bodySmall),
              const SizedBox(height: 16),
              if (!s.writing)
                ElevatedButton(onPressed: notifier.startWriting, child: const Text('My turn'))
              else ...[
                Text('Write your own sentence with “${card.word}” and this pattern.'),
                const SizedBox(height: 8),
                SentenceCheckField(
                  key: ValueKey('check-${card.rowId}'),
                  word: card.word,
                  translation: card.translation,
                  task: LearnCheckTask.pattern,
                  extra: card.pattern,
                  mode: SentenceCheckMode.practice,
                  onDone: notifier.done,
                ),
                if (result != null && result.verdict == null) ...[
                  const SizedBox(height: 8),
                  Text(practiceLabel(result.outcome), key: const ValueKey('pattern-skipped')),
                ],
                if (result != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
