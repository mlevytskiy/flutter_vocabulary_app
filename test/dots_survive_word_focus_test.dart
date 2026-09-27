import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// Regression for the reported bug: after the popup fix, tapping the Word field
/// just to raise the keyboard emptied the 3-dots button, even though the word
/// had not changed. The screen no longer drops its cached dictionary on a
/// keystroke; instead it keeps the block keyed to the word it was fetched for
/// and passes the dots button `_effectiveOptions(index)` -- the block while the
/// current Word still matches, null while it differs (word_input_screen.dart).
///
/// This test drives TranslationDotsButton the same way the screen does and
/// pins the visible contract it relies on: a block -> solid dots (Icons.circle),
/// null -> outlined dots (Icons.circle_outlined). The screen's derivation is a
/// pure word-equality check; here we feed it the same inputs a focus change,
/// an edit, and a revert produce, and confirm the icon follows.
void main() {
  // The exact shape word_input_screen.dart caches: Google's dictionary block.
  final block = TranslationResult(
    text: 'яблуко',
    dictionary: const [
      DictionaryEntry(
        pos: 'noun',
        words: [DictionaryWord(word: 'яблуко', backTranslations: ['apple'])],
      ),
    ],
  );

  // Mirrors _effectiveOptions: the block only while the current Word equals the
  // word it was fetched for. This is the value the screen hands the button.
  TranslationResult? effective({
    required String fetchedForWord,
    required String currentWord,
  }) {
    final current = currentWord.trim();
    if (current.isEmpty) return null;
    return fetchedForWord == current ? block : null;
  }

  Future<void> pumpDots(WidgetTester tester, TranslationResult? options) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TranslationDotsButton(
              controller: CustomPopupMenuControllerStub(),
              options: options,
              onSelectTranslation: (_) {},
              onLoadTranslations: () async => null,
              onOpen: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  bool solid() => find.byIcon(Icons.circle).evaluate().isNotEmpty;
  bool outlined() => find.byIcon(Icons.circle_outlined).evaluate().isNotEmpty;

  testWidgets('focus/no-op: word unchanged -> dots stay solid', (tester) async {
    // Block was fetched for "apple"; the current word is still "apple" (a mere
    // focus/selection change leaves the text alone).
    await pumpDots(
        tester, effective(fetchedForWord: 'apple', currentWord: 'apple'));
    expect(solid(), isTrue);
    expect(outlined(), isFalse);
  });

  testWidgets('edit then revert: outlined while changed, solid again on revert',
      (tester) async {
    // Start solid.
    await pumpDots(
        tester, effective(fetchedForWord: 'apple', currentWord: 'apple'));
    expect(solid(), isTrue);

    // Type a letter: "apple" -> "apples". The block no longer matches.
    await pumpDots(
        tester, effective(fetchedForWord: 'apple', currentWord: 'apples'));
    expect(outlined(), isTrue,
        reason: 'a changed word hides its stale block');

    // Delete it again: back to "apple", the same block matches and returns.
    await pumpDots(
        tester, effective(fetchedForWord: 'apple', currentWord: 'apple'));
    expect(solid(), isTrue,
        reason: 'reverting the edit restores the cached block');
  });

  testWidgets('empty word shows nothing', (tester) async {
    await pumpDots(
        tester, effective(fetchedForWord: 'apple', currentWord: ''));
    expect(outlined(), isTrue);
    expect(solid(), isFalse);
  });
}

/// A no-op controller so the button can build without wiring a real popup.
class CustomPopupMenuControllerStub extends CustomPopupMenuController {}
