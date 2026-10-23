import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'translate_sentences_notifier.dart';
import 'translate_sentences_page_body.dart';

/// The words of [words] the exam can ask about (a row id, a word and a
/// translation), in order; cut from [TranslateSentences.build].
List<WordPair> translateCandidates(List<WordPair> words) => <WordPair>[
      for (final w in words)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];

/// The cards of [candidates] from one Worker call of the kind `translate`
/// (S-15), in order; a word whose reply breaks S-57 gets no card. [words] is
/// the group: none of its English words may show on a card. Cut from
/// [TranslateSentences.build].
Future<List<TranslateCard>> translateCards(List<WordPair> words, List<WordPair> candidates, LearnApiService api) async {
  final replies = await api.fetchData(LearnDataKind.translate, [
    for (final w in candidates) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
  ]);
  final groupWords = [
    for (final w in words)
      if (w.word.trim().isNotEmpty) w.word.trim()
  ];
  final cards = <TranslateCard>[];
  for (final w in candidates) {
    final data = replies[w.rowId];
    final word = w.word.trim();
    if (data == null || data.cue.isEmpty || !data.source.contains(data.cue)) continue;
    if (!holdsWordOnce(data.model, word)) continue;
    // S-57: no English word of the group may show on the card.
    if (groupWords.any((g) => matchPlaces(data.source, g).isNotEmpty)) continue;
    cards.add(TranslateCard(
      rowId: w.rowId,
      word: word,
      translation: w.translation.trim(),
      source: data.source,
      cue: data.cue,
      model: data.model,
    ));
  }
  return cards;
}

/// Translate sentences' page source (learn-redesign ADR-0003): one step-3
/// page per word with a usable Worker reply, the session's words standing for
/// the group. The body runs its own AI check and reports the final word
/// through [PageAnswer.done] (right = `CheckRight`); it records no exam word
/// result (AC-15). Throws [LearnApiException] when the data cannot be loaded.
Future<List<ExercisePage>> translateSentencesPages(PageInput input) async {
  final candidates = translateCandidates(input.words);
  if (candidates.isEmpty) return const [];
  final cards = await translateCards(input.words, candidates, input.api);
  return [
    for (final card in cards)
      ExercisePage(
        exerciseId: translateExerciseId,
        exerciseName: 'Translate sentences',
        step: 3,
        rowIds: [card.rowId],
        body: (context, answer) => TranslateSentencesPageBody(
          card: card,
          onDone: (result) => answer.done({card.rowId: result.outcome == SentenceOutcome.right}),
        ),
      ),
  ];
}
