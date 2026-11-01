import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_collection.dart';
import '../../../core/story/word_grouping.dart' show wordsToLearn;
import '../../../router/routes.dart';
import '../session/session_results_screen.dart';
import 'flow_result.dart';
import 'learn_flow_notifier.dart';
import 'learn_flow_screen.dart';
import 'warm_up_view.dart';

/// Whether Learn may open the flow for [collection] (AC-01): at least
/// [minFlowWords] words to learn, the notifier's own rule.
bool canOpenLearnFlow(WordCollection? collection) =>
    collection != null && wordsToLearn(collection).length >= minFlowWords;

/// Opens the Learn flow of [collection] (AC-01), or shows
/// [flowTooFewWordsMessage] and opens nothing.
void openLearnFlow(BuildContext context, WordCollection? collection) {
  if (!canOpenLearnFlow(collection)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(flowTooFewWordsMessage)),
    );
    return;
  }
  LearnFlowRoute(collectionId: collection!.collectionId).push(context);
}

/// The Learn flow screen of [collectionId] with what each phase shows: the
/// warm-up, the main dialog (Talk, pushed over the flow) and the results.
class LearnFlowPage extends StatelessWidget {
  const LearnFlowPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context) {
    Widget warmUp(BuildContext context, LearnFlowState s, LearnFlow f) => Scaffold(
          appBar: WarmUpView.appBar(context, collectionId: collectionId),
          body: WarmUpView(collectionId: collectionId),
        );
    return LearnFlowScreen(
      collectionId: collectionId,
      phases: {
        FlowPhase.loading: warmUp,
        FlowPhase.warmUp: warmUp,
        FlowPhase.refused: (context, s, f) => const _Refused(),
        FlowPhase.dialog: (context, s, f) => _DialogLauncher(collectionId: collectionId),
        FlowPhase.results: (context, s, f) => SessionResultsScreen(flow: FlowResult.of(collectionId, s)),
      },
    );
  }
}

/// Pushes the main dialog's Talk screen once; the flow stays below it and
/// Talk pops back to it when the dialog ends (AC-13).
///
/// Talk closed before that (its own Leave, Back while it starts, Back on its
/// error) is the learner leaving the study: the flow leaves and closes too,
/// instead of staying on this empty page (owner, 2026-11-01).
class _DialogLauncher extends ConsumerStatefulWidget {
  const _DialogLauncher({required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<_DialogLauncher> createState() => _DialogLauncherState();
}

class _DialogLauncherState extends ConsumerState<_DialogLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TalkRoute(collectionId: widget.collectionId, learnFlow: true).push<void>(context);
      if (!mounted) return;
      final provider = learnFlowProvider(widget.collectionId);
      // Ended talks hand their result over before they pop (results phase).
      if (ref.read(provider).phase != FlowPhase.dialog) return;
      ref.read(provider.notifier).leave();
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Too few words after all (Learn checks first): the snackbar, then back.
class _Refused extends StatefulWidget {
  const _Refused();

  @override
  State<_Refused> createState() => _RefusedState();
}

class _RefusedState extends State<_Refused> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(flowTooFewWordsMessage)),
      );
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
