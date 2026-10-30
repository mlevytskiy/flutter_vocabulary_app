import 'learn_flow_notifier.dart';

/// What the session results screen needs to show a finished Learn flow
/// (learn-welcome AC-15, owner-brief Q10): the flow's [results], the
/// collection it played and the card words' row ids (for "Exercises").
class FlowResult {
  const FlowResult({
    required this.collectionId,
    required this.results,
    required this.cardRowIds,
  });

  /// The flow's results once [state] reached them; null before.
  static FlowResult? of(String collectionId, LearnFlowState state) {
    final results = state.results;
    if (results == null) return null;
    return FlowResult(
      collectionId: collectionId,
      results: results,
      cardRowIds: [
        for (final w in state.words)
          if (w.rowId.isNotEmpty) w.rowId
      ],
    );
  }

  final String collectionId;
  final LearnFlowResults results;

  /// The card words, in card order.
  final List<String> cardRowIds;
}
