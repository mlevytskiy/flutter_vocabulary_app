import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/match_board.dart';
import '../kit/match_rounds.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'match_synonyms_page_body.dart';

/// The usable words of Match synonyms (S-38, S-39): one Worker call for the
/// whole group. A failed call throws [LearnApiException].
Future<List<MatchPair>> matchSynonymsPairs(List<WordPair> group, LearnApiService api) async {
  final answers = await api.fetchData(LearnDataKind.synonym, [
    for (final w in group) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
  ]);
  return usableMatchPairs(group, {for (final e in answers.entries) e.key: e.value?.synonym});
}

/// One Match synonyms board: the words with their translation as the hint,
/// the synonyms shuffled out of order (S-35, S-36).
MatchRound matchSynonymsRound(List<MatchPair> pairs, Random random) => MatchRound(
      pairs: pairs,
      left: [
        for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.word), hint: p.translation.isEmpty ? null : p.translation),
      ],
      right: shuffledOutOfOrder([for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.answer))], random),
    );

/// Match synonyms as learn pages (learn-redesign ADR-0003, AC-08): one
/// step-1 board page per 3–4 usable words ([matchBoards]), each reporting
/// right-on-first-try per word through `answer.done` (AC-10). Fewer than 3
/// words ask nothing; a failed Worker call throws (AC-11).
Future<List<ExercisePage>> matchSynonymsPages(PageInput input) async {
  if (input.words.length < 3) return const [];
  final usable = await matchSynonymsPairs(input.words, input.api);
  return [
    for (final pairs in matchBoards(usable)) _page(matchSynonymsRound(pairs, input.random)),
  ];
}

ExercisePage _page(MatchRound round) => ExercisePage(
      exerciseId: 'match-synonyms',
      exerciseName: 'Match synonyms',
      step: 1,
      rowIds: [for (final p in round.pairs) p.rowId],
      body: (context, answer) => MatchBoardPage(
        key: ValueKey('match-synonyms-${round.pairs.first.rowId}'),
        left: round.left,
        right: round.right,
        answer: answer,
        builder: (context, links, onPair) => MatchSynonymsPageBody(
          left: round.left,
          right: round.right,
          links: links,
          onPair: onPair,
          expand: false,
        ),
      ),
    );
