import '../../../core/models/word_pair.dart';
import '../kit/sentence_check.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'explain_to_friend_notifier.dart';
import 'explain_to_friend_page_body.dart';

/// The cards of the usable [words] (a row id, a word and a translation), in
/// order; cut from [ExplainToFriend.build], which splits them into rounds.
List<ExplainCard> explainCards(List<WordPair> words) => <ExplainCard>[
      for (final WordPair w in words)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty)
          ExplainCard(rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ];

/// Explain it to a friend's page source (learn-redesign ADR-0003, sad §5.1):
/// one step-3 page per usable word in the typed mode, with no mode question.
/// The body runs its own AI check and reports the final word through
/// [PageAnswer.done] (right = `CheckRight`); it records no exam word result
/// (AC-15).
Future<List<ExercisePage>> explainToFriendPages(PageInput input) async => [
      for (final card in explainCards(input.words))
        ExercisePage(
          exerciseId: explainExerciseId,
          exerciseName: 'Explain it to a friend',
          step: 3,
          rowIds: [card.rowId],
          body: (context, answer) => ExplainToFriendPageBody.typed(
            card: card,
            onDone: (result) => answer.done({card.rowId: result.outcome == SentenceOutcome.right}),
          ),
        ),
    ];
