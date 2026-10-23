import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'remember_or_not_notifier.dart';
import 'remember_or_not_page_body.dart';

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
    ref.listen(provider.select((a) => a.value?.shown), (_, __) => _pronunciation.stop());
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Card ${s.position} of ${s.total}'),
              const SizedBox(height: 16),
              RememberOrNotPageBody(
                card: card,
                flipped: s.flipped,
                onFlip: notifier.flip,
                onSpeak: (accent) => _speak(card.word, accent),
                rememberedLabel: s.secondShowing ? 'Got it' : 'Remembered',
                notLabel: s.secondShowing ? 'Still not' : 'Not yet',
                onRate: notifier.rate,
              ),
            ],
          ),
        );
      },
    );
  }
}
