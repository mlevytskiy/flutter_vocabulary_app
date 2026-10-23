import '../../../core/models/word_pair.dart';
import '../kit/sentence_check.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'own_sentences_notifier.dart';
import 'own_sentences_page_body.dart';

/// The cards of the usable [words] (a row id, a word and a translation), in
/// order; cut from [OwnSentences.build], which splits them into rounds.
List<OwnCard> ownCards(List<WordPair> words) => <OwnCard>[
      for (final WordPair w in words)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty)
          OwnCard(rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ];

/// Make your own sentences' page source (learn-redesign ADR-0003): one step-3
/// page per usable word. The body runs its own AI check and reports the final
/// word through [PageAnswer.done] (right = `CheckRight`); it records no exam
/// word result (AC-15).
Future<List<ExercisePage>> ownSentencesPages(PageInput input) async => [
      for (final card in ownCards(input.words))
        ExercisePage(
          exerciseId: ownExerciseId,
          exerciseName: 'Make your own sentences',
          step: 3,
          rowIds: [card.rowId],
          body: (context, answer) => OwnSentencesPageBody(
            card: card,
            onDone: (result) => answer.done({card.rowId: result.outcome == SentenceOutcome.right}),
          ),
        ),
    ];
