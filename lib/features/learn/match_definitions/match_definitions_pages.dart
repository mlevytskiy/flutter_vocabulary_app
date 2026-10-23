import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/definition_text.dart';
import '../kit/match_board.dart';
import '../kit/match_rounds.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'match_definitions_page_body.dart';

/// The usable words of Match word and definition (S-38, S-42): a word's
/// stored definition line first, else one Worker call for the words without
/// one. A failed call throws [LearnApiException].
Future<List<MatchPair>> matchDefinitionsPairs(List<WordPair> group, LearnApiService api) async {
  // Stored line (S-40) first; a word with no stored line is asked (S-42).
  final answers = <String, String?>{};
  final asked = [
    for (final w in group)
      if (definitionText(w.definition).isEmpty) w,
  ];
  for (final w in group) {
    if (definitionText(w.definition).isNotEmpty) answers[w.rowId] = definitionCard(w.definition, w.word);
  }
  if (asked.isNotEmpty) {
    final fetched = await api.fetchData(LearnDataKind.definition, [
      for (final w in asked) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    for (final w in asked) {
      final text = fetched[w.rowId]?.definition;
      answers[w.rowId] = text == null ? null : definitionCard(text, w.word);
    }
  }
  return usableMatchPairs(group, answers);
}

/// One Match word and definition board: the words, their definitions
/// shuffled out of order (S-35, S-36).
MatchRound matchDefinitionsRound(List<MatchPair> pairs, Random random) => MatchRound(
      pairs: pairs,
      left: [for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.word))],
      // The answer is already card text (S-40); cutting twice could cut again.
      right: shuffledOutOfOrder([for (final p in pairs) MatchItem(id: p.rowId, text: p.answer)], random),
    );

/// Match word and definition as learn pages (learn-redesign ADR-0003, AC-08):
/// one step-1 board page per 3–4 usable words ([matchBoards]), each
/// reporting right-on-first-try per word through `answer.done` (AC-10).
/// Fewer than 3 words ask nothing; a failed Worker call throws (AC-11).
Future<List<ExercisePage>> matchDefinitionsPages(PageInput input) async {
  if (input.words.length < 3) return const [];
  final usable = await matchDefinitionsPairs(input.words, input.api);
  return [
    for (final pairs in matchBoards(usable)) _page(matchDefinitionsRound(pairs, input.random)),
  ];
}

ExercisePage _page(MatchRound round) => ExercisePage(
      exerciseId: 'match-definitions',
      exerciseName: 'Match word and definition',
      step: 1,
      rowIds: [for (final p in round.pairs) p.rowId],
      body: (context, answer) => MatchBoardPage(
        key: ValueKey('match-definitions-${round.pairs.first.rowId}'),
        left: round.left,
        right: round.right,
        answer: answer,
        builder: (context, links, onPair) => MatchDefinitionsPageBody(
          left: round.left,
          right: round.right,
          links: links,
          onPair: onPair,
          expand: false,
        ),
      ),
    );
