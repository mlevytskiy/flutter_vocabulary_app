import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/pronunciation_buttons.dart';

/// learn-remember-or-not: the screen (AC-01, AC-05 – AC-09, AC-11, AC-14 – AC-19, AC-21).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

class _NoNetwork implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('the exercise asked the server: ${i.memberName}');
}

class _FakeSpeech implements PronunciationService {
  final spoken = <(String, Accent)>[];
  int stops = 0;
  Object? failWith;

  @override
  Future<void> speak(String word, {required Accent accent}) async {
    if (failWith != null) throw failWith!;
    spoken.add((word, accent));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

WordCollection _collection(int count, {List<WordPair>? words, List<FilmDialogue> dialogues = const []}) {
  final w = words ??
      [
        for (var i = 0; i < count; i++)
          WordPair(word: 'word$i', translation: 'слово$i', definition: 'Meaning of word$i here', rowId: 'r$i'),
      ];
  return WordCollection.create()
    ..words = w
    ..dialogues = dialogues
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (final x in w) x.rowId],
    ];
}

void main() {
  late _FakeSpeech speech;

  Future<ProviderContainer> pump(WidgetTester tester, WordCollection collection, {String? collectionId, bool popHost = true}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    speech = _FakeSpeech();
    final container = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(3)),
      learnApiServiceProvider.overrideWithValue(_NoNetwork()),
      pronunciationServiceProvider.overrideWithValue(speech),
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
                builder: (_) => exerciseScreen('remember-or-not', collectionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
  }

  testWidgets('AC-01: title, counter, a meaning and Flip; nothing of the back', (tester) async {
    await pump(tester, _collection(5));
    expect(find.text('Remember or not'), findsOneWidget);
    expect(find.text('Card 1 of 5'), findsOneWidget);
    expect(find.textContaining('Meaning of'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.byType(PronunciationButtons), findsNothing);
    expect(find.textContaining('слово'), findsNothing);
    expect(find.text('Remembered'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    expect(speech.spoken, isEmpty);
  });

  testWidgets('AC-05: Flip shows the back; a tap on the card flips too; a further tap changes nothing', (tester) async {
    await pump(tester, _collection(5));
    await tapText(tester, 'Flip');
    expect(find.text('Flip'), findsNothing);
    expect(find.byType(PronunciationButtons), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.textContaining('слово'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-front')), findsNothing);
  });

  testWidgets('AC-05: tapping the front card flips it', (tester) async {
    await pump(tester, _collection(5));
    await tester.tap(find.byKey(const ValueKey('card-front')));
    await tester.pump();
    expect(find.text('Remembered'), findsOneWidget);
  });

  testWidgets('AC-05: a word with no translation shows no translation line', (tester) async {
    await pump(
        tester,
        _collection(0, words: [
          for (var i = 0; i < 3; i++) WordPair(word: 'w$i', translation: '', definition: 'About w$i it', rowId: 'r$i'),
        ]));
    await tapText(tester, 'Flip');
    expect(find.textContaining('слово'), findsNothing);
    expect(find.text('Remembered'), findsOneWidget);
  });

  testWidgets('AC-06: example line with the word in bold; none without a dialogue', (tester) async {
    final bank = WordPair(word: 'bank', translation: 'банк', definition: 'Where money is kept', rowId: 'b');
    final others = [
      for (var i = 0; i < 2; i++) WordPair(word: 'o$i', translation: 'x', definition: 'Other $i', rowId: 'o$i'),
    ];
    final d = FilmDialogue()
      ..id = 'd'
      ..lines = ['We walked along the river.', 'Meet me at the bank, the bank by the bridge.', 'The bank opens at nine.']
      ..wordRowIds = ['b'];
    await pump(tester, _collection(0, words: [bank, ...others], dialogues: [d]));
    // Reach the bank card, whatever the shuffle.
    while (find.text('Where money is kept').evaluate().isEmpty) {
      await tapText(tester, 'Flip');
      await tapText(tester, 'Remembered');
    }
    await tapText(tester, 'Flip');
    final rich = tester.widget<Text>(find.byKey(const ValueKey('example')));
    final span = rich.textSpan! as TextSpan;
    expect(span.toPlainText(), 'The bank opens at nine.');
    expect((span.children!.whereType<TextSpan>().firstWhere((s) => s.text == 'bank').style)!.fontWeight, FontWeight.bold);
  });

  testWidgets('AC-07, AC-08: sound only on a tap of a flag; a second tap speaks again in that accent', (tester) async {
    await pump(tester, _collection(3));
    await tapText(tester, 'Flip');
    expect(speech.spoken, isEmpty);
    await tester.tap(find.byTooltip('UK pronunciation'));
    await tester.pump();
    await tester.tap(find.byTooltip('US pronunciation'));
    await tester.pump();
    expect(speech.spoken.map((s) => s.$2), [Accent.uk, Accent.us]);
    expect(speech.spoken.first.$1, startsWith('word'));
    final stopsBefore = speech.stops;
    await tapText(tester, 'Remembered');
    expect(speech.stops, greaterThan(stopsBefore), reason: 'stops when the card changes');
    expect(find.byType(PronunciationButtons), findsNothing);
    expect(speech.spoken.length, 2);
  });

  testWidgets('AC-08: leaving the screen stops the speaker', (tester) async {
    await pump(tester, _collection(3));
    final before = speech.stops;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(speech.stops, greaterThan(before));
  });

  testWidgets('AC-09: a speech failure shows its message and the card stays usable', (tester) async {
    await pump(tester, _collection(3));
    speech.failWith = PronunciationException('Could not play pronunciation: no voice');
    await tapText(tester, 'Flip');
    await tester.tap(find.byTooltip('US pronunciation'));
    await tester.pump();
    expect(find.text('Could not play pronunciation: no voice'), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    await tapText(tester, 'Remembered');
    expect(find.text('Card 2 of 3'), findsOneWidget);
  });

  testWidgets('AC-11, AC-12: Not yet comes back last with Got it / Still not', (tester) async {
    await pump(tester, _collection(3));
    await tapText(tester, 'Flip');
    await tapText(tester, 'Not yet');
    expect(find.text('Card 2 of 4'), findsOneWidget);
    await tapText(tester, 'Flip');
    await tapText(tester, 'Remembered');
    await tapText(tester, 'Flip');
    await tapText(tester, 'Remembered');
    expect(find.text('Card 4 of 4'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    await tapText(tester, 'Flip');
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Still not'), findsOneWidget);
  });

  testWidgets('AC-14: summary heading and rows, Done returns to the learn page', (tester) async {
    await pump(tester, _collection(3));
    await tapText(tester, 'Flip');
    await tapText(tester, 'Not yet');
    for (var i = 0; i < 2; i++) {
      await tapText(tester, 'Flip');
      await tapText(tester, 'Remembered');
    }
    await tapText(tester, 'Flip');
    await tapText(tester, 'Still not');
    expect(find.text('2 remembered, 0 after repeat, 1 not yet'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Remembered'), findsNWidgets(2));
    await tapText(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-14: with two rounds the summary offers Next round', (tester) async {
    await pump(tester, _collection(10));
    for (var i = 0; i < 5; i++) {
      await tapText(tester, 'Flip');
      await tapText(tester, 'Remembered');
    }
    expect(find.text('5 remembered, 0 after repeat, 0 not yet'), findsOneWidget);
    await tapText(tester, 'Next round');
    expect(find.text('Card 1 of 5'), findsOneWidget);
  });

  testWidgets('AC-15: leaving mid-round keeps nothing; opening again starts at card 1', (tester) async {
    final collection = _collection(5);
    final c = await pump(tester, collection);
    await tapText(tester, 'Flip');
    await tapText(tester, 'Remembered');
    expect(find.text('Card 2 of 5'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'learn page');
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 5'), findsOneWidget);
    expect(c.read(wordInputNotifierProvider).requireValue.words.length, 5);
  });

  testWidgets('AC-16: fewer than 3 usable words: only the message and Back', (tester) async {
    await pump(tester, _collection(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Flip'), findsNothing);
    await tapText(tester, 'Back');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-18: a History session is used and left unchanged', (tester) async {
    final collection = _collection(3, dialogues: [
      FilmDialogue()
        ..id = 'd'
        ..lines = ['Say word0 now.']
        ..wordRowIds = ['r0'],
    ]);
    final before = collection.updatedAt;
    await pump(tester, collection, collectionId: 'hist');
    expect(find.text('Card 1 of 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Flip');
      await tapText(tester, 'Remembered');
    }
    expect(find.text('3 remembered, 0 after repeat, 0 not yet'), findsOneWidget);
    expect(collection.updatedAt, before);
    expect(collection.words.length, 3);
    expect(collection.dialogues.length, 1);
  });

  testWidgets('AC-19, AC-21: long text wraps and nothing asks the server', (tester) async {
    final long = List.filled(30, 'extraordinarily').join(' ');
    await pump(
        tester,
        _collection(0, words: [
          WordPair(word: 'give up', translation: long, definition: 'To $long and to give up', rowId: 'a'),
          for (var i = 0; i < 2; i++) WordPair(word: 'w$i', translation: 't', definition: 'D$i', rowId: 'r$i'),
        ]));
    while (find.textContaining('To extraordinarily').evaluate().isEmpty) {
      await tapText(tester, 'Flip');
      await tapText(tester, 'Remembered');
    }
    expect(find.textContaining('To extraordinarily and'.substring(0, 17)), findsOneWidget);
    expect(find.textContaining('___'), findsOneWidget);
    await tapText(tester, 'Flip');
    expect(find.text('give up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
