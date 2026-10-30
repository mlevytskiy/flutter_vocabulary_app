import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router/routes.dart';
import '../../../core/models/word_origin.dart';
import '../../../core/models/word_pair.dart';
import 'exercise_page.dart';
import 'learn_page_frame.dart';
import 'learning_session_notifier.dart';
import 'self_check_card.dart';

/// The learning session (learn-redesign SCR-03; AC-02, AC-08, AC-11, AC-16):
/// the pages of [LearningSession] in the [LearnPageFrame], the error line with
/// Retry above it, and the leave dialog. Opened by `LearningSessionRoute`.
class LearningSessionScreen extends ConsumerStatefulWidget {
  const LearningSessionScreen({super.key, this.collectionId, this.split = true, this.rowIds, this.skipGroup});

  /// Null for the current collection, as on `LearnRoute`.
  final String? collectionId;

  /// Whether the Learn sheet's split was ticked.
  final bool split;

  /// Exactly these rows ("Practise N shaky words"), else null.
  final List<String>? rowIds;

  /// "Next group": the group just played, skipped by the picker.
  final int? skipGroup;

  static const leaveText = 'Leave the session? Progress in this session is lost.';

  @override
  ConsumerState<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends ConsumerState<LearningSessionScreen> {
  @override
  void initState() {
    super.initState();
    // After the first build has subscribed, so the auto-dispose session lives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(learningSessionProvider(widget.collectionId).notifier).start(split: widget.split, rowIds: widget.rowIds, skipGroup: widget.skipGroup, checkCards: true);
    });
  }

  final _cardAnswer = PageAnswer();

  @override
  void dispose() {
    _cardAnswer.dispose();
    super.dispose();
  }

  /// A due self-check card as a page: the frame's step bar and page counter
  /// and the card, no Check button and no verdict bar (self-check-cards AC-03).
  Widget _checkFrame(LearningSessionState s, LearningSession notifier) {
    final id = s.checkCard!;
    final WordPair? row = (s.pick?.words ?? const <WordPair>[]).where((w) => w.rowId == id).firstOrNull;
    if (row == null) return const SizedBox.shrink();
    return LearnPageFrame(
      step: s.step,
      stepProgress: s.stepProgress,
      page: s.pageNumber,
      total: s.pageTotal,
      chip: 'Self-check',
      isCard: true,
      body: KeyedSubtree(
        key: ValueKey('check-$id-${s.pageIndex}'),
        child: SelfCheckCard(
          row: row,
          box: s.checkBox,
          side: s.checkSide,
          now: DateTime.now(),
          afterMistake: s.checkAfterMistake,
          wordContext: row.context,
          contextByAi: row.contextKind == ContextKind.ai,
          onRated: notifier.rateCheck,
        ),
      ),
      answer: _cardAnswer,
      onContinue: () {},
      onClose: _confirmLeave,
      onResult: (_) {},
    );
  }

  /// Asks before leaving a session in progress; Leave pops and writes
  /// nothing (AC-16).
  Future<void> _confirmLeave() async {
    final leave = await confirmLeaveSession(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = learningSessionProvider(widget.collectionId);
    final s = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    // Finished: the results replace the session (AC-12).
    ref.listen(provider.select((s) => s.status), (_, status) {
      if (status == SessionStatus.finished && mounted) {
        SessionResultsRoute(collectionId: widget.collectionId).pushReplacement(context);
      }
    });
    final inProgress = s.status == SessionStatus.playing;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (s.status) {
            SessionStatus.loading => const _Message(text: 'Preparing your session…', busy: true),
            SessionStatus.notEnough => _Message(
                text: 'Not enough words to learn yet',
                button: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            SessionStatus.error => _Message(
                text: 'Could not load some exercises',
                button: 'Retry',
                onPressed: notifier.retry,
              ),
            SessionStatus.finished => const _Message(text: 'Preparing your results…', busy: true),
            SessionStatus.playing => Column(
                children: [
                  if (s.loadFailed) _ErrorLine(onRetry: notifier.retry),
                  Expanded(
                    child: s.checkCard != null
                        ? _checkFrame(s, notifier)
                        : LearnPageFrame(
                      step: s.step,
                      stepProgress: s.stepProgress,
                      page: s.pageNumber,
                      total: s.pageTotal,
                      chip: s.page!.exerciseName,
                      // A fresh subtree per page, so no body state carries over.
                      body: KeyedSubtree(
                        key: ValueKey(s.pageIndex),
                        child: Builder(builder: (context) => s.page!.body(context, s.answer!)),
                      ),
                      answer: s.answer!,
                      verdict: s.verdict,
                      onContinue: notifier.next,
                      onClose: _confirmLeave,
                      onResult: notifier.answer,
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

/// The leave dialog of a learning session (learn-redesign AC-16), shared
/// with the Learn flow (learn-welcome AC-16): true when Leave was tapped.
Future<bool> confirmLeaveSession(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: const Text(LearningSessionScreen.leaveText),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
      ],
    ),
  );
  return leave == true;
}

/// The one plain error line with Retry while other pages play (AC-11).
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text('Could not load some exercises',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.busy = false, this.button, this.onPressed});

  final String text;
  final bool busy;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (button != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(button!)),
              ],
            ],
          ),
        ),
      );
}
