import 'package:flutter/material.dart';

import '../kit/match_board.dart';

/// One Match word and definition board (cut from [MatchDefinitionsScreen]'s round builder),
/// drawn by the exercise screen and by a learn page (learn-redesign ADR-0003).
class MatchDefinitionsPageBody extends StatelessWidget {
  const MatchDefinitionsPageBody({
    super.key,
    this.roundLabel,
    this.boardKey,
    required this.left,
    required this.right,
    required this.links,
    required this.onPair,
    this.expand = true,
  });

  final String? roundLabel;
  final Key? boardKey;
  final List<MatchItem> left;
  final List<MatchItem> right;
  final Map<String, String> links;
  final bool Function(String leftId, String rightId) onPair;
  final bool expand;

  @override
  Widget build(BuildContext context) => MatchRoundBody(
        prompt: 'Tap a word, then its definition',
        roundLabel: roundLabel,
        boardKey: boardKey,
        left: left,
        right: right,
        links: links,
        onPair: onPair,
        expand: expand,
      );
}
