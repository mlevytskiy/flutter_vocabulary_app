import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_pair.dart';
import '../exercises.dart';
import '../kit/example_line.dart';
import '../kit/word_marks.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'remember_or_not_page_body.dart';

class FlashCard {
  const FlashCard({
    required this.rowId,
    required this.word,
    required this.front,
    required this.translation,
    this.example,
  });

  final String rowId;
  final String word;
  final String front;
  final String translation;
  final String? example;
}

final _letter = RegExp(r'\p{L}', unicode: true);

String? _maskedWithLetters(String text, String word) {
  final masked = maskWord(text.trim(), word);
  return masked.replaceAll('___', '').contains(_letter) ? masked : null;
}

/// The front of a card: the masked definition, else the masked translation
/// (D-08, D-16); null when neither keeps a letter, so the word is not usable.
String? frontFor(WordPair w) {
  final word = w.word.trim();
  if (word.isEmpty) return null;
  return _maskedWithLetters(w.definition, word) ?? _maskedWithLetters(w.translation, word);
}

/// The cards of [group] (D-08, D-16): one per word with a front that keeps a
/// letter, in group order. Shared by [rememberOrNotPages] and the old notifier
/// (learn-redesign ADR-0003).
List<FlashCard> rememberCards(List<WordPair> group, List<FilmDialogue> dialogues) => <FlashCard>[
      for (final w in group)
        if (frontFor(w) case final front?)
          FlashCard(
            rowId: w.rowId,
            word: w.word.trim(),
            front: front,
            translation: w.translation.trim(),
            example: exampleLineFor(w, dialogues),
          ),
    ];

final _exercise = exercises.firstWhere((e) => e.id == 'remember-or-not');

/// Remember or not's page source (learn-redesign ADR-0003): one page per card.
/// It needs no AI data (AC-11); "I knew it" / "I didn't" report the page
/// through [PageAnswer.done], "I didn't" as a miss (AC-09).
Future<List<ExercisePage>> rememberOrNotPages(PageInput input) async => [
      for (final card in rememberCards(input.words, input.dialogues))
        ExercisePage(
          exerciseId: _exercise.id,
          exerciseName: _exercise.name,
          step: _exercise.stage,
          rowIds: [card.rowId],
          body: (context, answer) => RememberOrNotSessionBody(card: card, answer: answer),
        ),
    ];
