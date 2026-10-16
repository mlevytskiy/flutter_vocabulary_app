import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-fill-the-gaps: the screen (AC-01 – AC-13, AC-15, AC-22 – AC-28).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

/// Counts every call; answers "We <word> it on the day." unless told otherwise.
class _Api implements LearnApiService {
  Object? error;
  Completer<void>? gate;
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return {for (final w in words) w.rowId: (sentence: 'We ${w.word} it on the day.') as T};
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// Words named [names] (or word0…), each with a translation; [lines] are dialogue
/// lines linking every word that has one.
WordCollection _collection(int count, {List<String>? names, Map<String, String> lines = const {}}) {
  final words = [
    for (var i = 0; i < count; i++)
      WordPair(word: names != null ? names[i] : 'word$i', translation: 'слово$i', rowId: 'r$i'),
  ];
  return WordCollection.create()
    ..words = words
    ..dialogues = [
      for (final e in lines.entries)
        FilmDialogue()
          ..id = 'd-${e.key}'
          ..lines = [e.value]
          ..wordRowIds = [for (final w in words) if (w.word == e.key) w.rowId],
    ]
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (final w in words) w.rowId],
    ];
}

Map<String, String> _lines(List<String> names) => {for (final n in names) n: 'We $n it on the day.'};

void main() {
  late _Api api;

  Future<ProviderContainer> pump(WidgetTester tester, WordCollection collection, {String? collectionId, bool settle = true}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(collection)),
      collectionByIdProvider('hist').overrideWith((ref) async => collection),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('fill-the-gaps', collectionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    return container;
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  setUp(() => api = _Api());

  testWidgets('AC-01, AC-02: title, counter, instruction, gap sentence and cue; keyboard field; no Worker call', (tester) async {
    await pump(tester, _collection(5, lines: _lines([for (var i = 0; i < 5; i++) 'word$i'])));
    expect(find.text('Fill the gaps'), findsOneWidget);
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.text('Type the missing word'), findsOneWidget);
    expect(find.text('We ___ it on the day.'), findsOneWidget);
    expect(find.text('слово0'), findsOneWidget);
    expect(find.textContaining('word0'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(api.calls, isEmpty);
  });

  testWidgets('AC-02: a phrase makes one gap; a cue with the English word shows ___', (tester) async {
    final s = _collection(3, names: ['give up', 'tide', 'bay'], lines: {'give up': 'You must never give up now.'});
    s.words[0].translation = 'give up (здаватися)';
    await pump(tester, s);
    expect(find.text('You must never ___ now.'), findsOneWidget);
    expect(find.text('___ (здаватися)'), findsOneWidget);
  });

  testWidgets('AC-03: right at once, ignoring case and spaces: Right, bold word, read-only, Next, 1st try', (tester) async {
    await pump(tester, _collection(3, names: ['received', 'receive', 'cat'], lines: _lines(['received', 'receive', 'cat'])));
    await send(tester, 'Received ');
    expect(find.text('Right'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Right')).style!.color, Colors.green);
    final sentence = tester.widget<Text>(find.byKey(const ValueKey('gap-sentence')));
    expect((sentence.textSpan! as TextSpan).toPlainText(), 'We received it on the day.');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('Show answer'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('AC-04: one typo on a long word is right with "Almost: receive"', (tester) async {
    await pump(tester, _collection(3, names: ['receive', 'received', 'cat'], lines: _lines(['receive', 'received', 'cat'])));
    await send(tester, 'recieve');
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Almost: receive'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('AC-05, AC-06: wrong gives the hint and one more try, keeping the text; another form is wrong', (tester) async {
    await pump(tester, _collection(3, names: ['cat', 'walk', 'give up'], lines: _lines(['cat', 'walk', 'give up'])));
    await send(tester, 'cot');
    expect(find.text('Right'), findsNothing);
    expect(find.text('Starts with “c”, 3 letters'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await send(tester, 'cat');
    expect(find.text('Right'), findsOneWidget);
    await tapText(tester, 'Next');
    await send(tester, 'walked');
    expect(find.text('Starts with “w”, 4 letters'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'walked');
  });

  testWidgets('AC-08, AC-09: a second miss and Show answer both end Missed with the answer', (tester) async {
    await pump(tester, _collection(3, names: ['walk', 'cat', 'tide'], lines: _lines(['walk', 'cat', 'tide'])));
    await send(tester, 'run');
    await send(tester, 'jog');
    expect(find.text('Missed'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Missed')).style!.color, Colors.red);
    expect(find.text('Answer: walk'), findsOneWidget);
    final sentence = tester.widget<Text>(find.byKey(const ValueKey('gap-sentence')));
    expect((sentence.textSpan! as TextSpan).toPlainText(), 'We walk it on the day.');
    await tapText(tester, 'Next');
    await tapText(tester, 'Show answer');
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Answer: cat'), findsOneWidget);
  });

  testWidgets('AC-10, AC-11: empty or spaces do nothing; after the final answer nothing changes', (tester) async {
    await pump(tester, _collection(3, names: ['walk', 'cat', 'tide'], lines: _lines(['walk', 'cat', 'tide'])));
    await send(tester, '   ');
    await send(tester, '');
    expect(find.textContaining('Starts with'), findsNothing);
    expect(find.text('Missed'), findsNothing);
    await send(tester, 'walk');
    expect(find.text('Right'), findsOneWidget);
    await send(tester, 'other');
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Missed'), findsNothing);
  });

  testWidgets('AC-12: a leading to/the is ignored on both sides', (tester) async {
    await pump(tester, _collection(3, names: ['give up', 'the shore', 'tide'], lines: _lines(['give up', 'the shore', 'tide'])));
    await send(tester, 'to give up');
    expect(find.text('Right'), findsOneWidget);
    await tapText(tester, 'Next');
    await send(tester, 'shore');
    expect(find.text('Right'), findsOneWidget);
  });

  testWidgets('AC-13: Next gives the next question with an empty field; the last Next opens the summary', (tester) async {
    await pump(tester, _collection(3, lines: _lines(['word0', 'word1', 'word2'])));
    await send(tester, 'word0');
    await tapText(tester, 'Next');
    expect(find.text('Question 2 of 3'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await send(tester, 'word1');
    await tapText(tester, 'Next');
    await send(tester, 'word2');
    await tapText(tester, 'Next');
    expect(find.textContaining('Score:'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('AC-15: the Worker is asked once, for the words without a dialogue sentence', (tester) async {
    await pump(tester, _collection(4, lines: _lines(['word0', 'word1'])));
    expect(api.calls, hasLength(1));
    expect(api.calls.single.map((w) => w.rowId), ['r2', 'r3']);
    expect(api.calls.single.map((w) => w.translation), ['слово2', 'слово3']);
    await send(tester, 'word0');
    await tapText(tester, 'Next');
    await send(tester, 'word1');
    await tapText(tester, 'Next');
    expect(find.text('We ___ it on the day.'), findsOneWidget);
    expect(api.calls, hasLength(1));
  });

  testWidgets('AC-22, AC-23: not enough words shows only the line and Back (no call under 3 words)', (tester) async {
    await pump(tester, _collection(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('AC-23: 3 words of which fewer than 3 get a sentence: not enough, Back returns', (tester) async {
    api = _NoneApi();
    await pump(tester, _collection(3));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-24: a failed call shows the error line and Retry; back online Retry shows question 1', (tester) async {
    api.error = LearnApiException(LearnApiError.network, 'down');
    await pump(tester, _collection(3, lines: _lines(['word0'])));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    api.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(api.calls, hasLength(2));
  });

  testWidgets('AC-25: day limit shows its line and Back; too many requests shows its line and Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, 'cap');
    await pump(tester, _collection(3));
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('AC-25: rate limited', (tester) async {
    api.error = LearnApiException(LearnApiError.rateLimited, 'fast');
    await pump(tester, _collection(3));
    expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-26: the summary lists results in group order with the score; Next round, then Done', (tester) async {
    await pump(tester, _collection(12, lines: _lines([for (var i = 0; i < 12; i++) 'word$i'])));
    // round 1 of 6: 1st, 1st, 2nd, missed (shown), 1st, 1st
    await send(tester, 'word0');
    await tapText(tester, 'Next');
    await send(tester, 'word1');
    await tapText(tester, 'Next');
    await send(tester, 'nope');
    await send(tester, 'word2');
    await tapText(tester, 'Next');
    await tapText(tester, 'Show answer');
    await tapText(tester, 'Next');
    await send(tester, 'word4');
    await tapText(tester, 'Next');
    await send(tester, 'word5');
    await tapText(tester, 'Next');
    expect(find.text('Score: 9 of 12'), findsOneWidget);
    String trailing(int i) => tester.widget<Text>(find.descendant(
        of: find.byKey(ValueKey('outcome-r$i')), matching: find.byType(Text)).last).data!;
    expect([for (var i = 0; i < 6; i++) trailing(i)], ['1st try', '1st try', '2nd try', 'Missed', '1st try', '1st try']);
    await tester.tap(find.text('Next round'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 6'), findsOneWidget);
    expect(find.text('We ___ it on the day.'), findsOneWidget);
    for (var i = 6; i < 12; i++) {
      await send(tester, 'word$i');
      await tapText(tester, 'Next');
    }
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-27, AC-28: History session used and unchanged; leaving keeps nothing', (tester) async {
    final hist = _collection(4, lines: _lines(['word0', 'word1']));
    final before = hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList();
    final updated = hist.updatedAt;
    final lines = hist.dialogues.map((d) => d.lines.join('|')).toList();
    await pump(tester, hist, collectionId: 'hist');
    expect(api.calls.single.map((w) => w.rowId), ['r2', 'r3']);
    await send(tester, 'word0');
    await tapText(tester, 'Next');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 4'), findsOneWidget);
    expect(hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList(), before);
    expect(hist.dialogues.map((d) => d.lines.join('|')).toList(), lines);
    expect(hist.updatedAt, updated);
  });
}

class _NoneApi extends _Api {
  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    return {for (final w in words) w.rowId: null};
  }
}
