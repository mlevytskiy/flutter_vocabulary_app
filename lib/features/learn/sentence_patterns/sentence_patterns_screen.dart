import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'sentence_patterns_notifier.dart';
import 'sentence_patterns_page_body.dart';

class SentencePatternsScreen extends ConsumerStatefulWidget {
  const SentencePatternsScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
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
    final provider = sentencePatternsProvider(widget.collectionId, widget.groupId);
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word ${s.index + 1} of ${s.cards.length}'),
              const SizedBox(height: 16),
              SentencePatternsPageBody(
                card: card,
                writing: s.writing,
                result: result,
                onStartWriting: notifier.startWriting,
                onDone: notifier.done,
                onSpeak: (accent) => _speak(card.sentence, accent),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
              ],
            ],
          ),
        );
      },
    );
  }
}
