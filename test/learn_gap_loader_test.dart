import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/gap_question.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_answer_field.dart';

/// learn-fill-the-gaps S-44 and S-45: the loader and the prompt (AC-14, AC-15, AC-20, AC-24, AC-30).
class _Api implements LearnApiService {
  _Api([this.sentences = const {}, this.error]);
  final Map<String, String?> sentences;
  final Object? error;
  final calls = <(LearnDataKind<Object?>, List<LearnWord>)>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add((kind, words));
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: sentences[w.word] == null ? null : (sentence: sentences[w.word]!) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

void main() {
  WordPair w(int i, {String? word, String translation = 'пер'}) =>
      WordPair(word: word ?? 'word$i', translation: translation, rowId: 'r$i');

  FilmDialogue d(List<String> lines, List<String> ids) => FilmDialogue()
    ..id = 'd'
    ..lines = lines
    ..wordRowIds = ids;

  group('loadGapQuestions', () {
    test('AC-15: dialogue lines first; one call for the rest, with trimmed words and translations', () async {
      final words = [w(0, word: 'harbour'), w(1, word: ' walk ', translation: ' ходити '), w(2, word: 'tide')];
      final api = _Api({'walk': 'We walk to the station now.', 'tide': 'The tide comes in so fast.'});
      final got = await loadGapQuestions(words, [d(['The harbour is closed tonight.'], ['r0'])], api);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.$1, same(LearnDataKind.sentence));
      expect(api.calls.single.$2, [
        (rowId: 'r1', word: 'walk', translation: 'ходити'),
        (rowId: 'r2', word: 'tide', translation: 'пер'),
      ]);
      expect(got.keys, ['r0', 'r1', 'r2']);
      expect(got['r0']!.source, GapSource.dialogue);
      expect(got['r1']!.source, GapSource.worker);
      expect(got['r1']!.masked, 'We ___ to the station now.');
    });

    test('AC-14/15: no call when every word has a dialogue sentence', () async {
      final api = _Api();
      final got = await loadGapQuestions([w(0, word: 'harbour')], [d(['The harbour is closed tonight.'], ['r0'])], api);
      expect(got.keys, ['r0']);
      expect(api.calls, isEmpty);
    });

    test('AC-20: no word, no translation or no row id is sent; a Worker null or an unfair sentence leaves the word out', () async {
      final api = _Api({'walk': null, 'tide': 'The tides come in so fast.', 'cove': 'The cove is very quiet today.'});
      final words = [
        w(0, word: 'walk'),
        w(1, word: 'tide'),
        w(2, word: 'cove'),
        w(3, word: 'bay', translation: ' '),
        w(4, word: ' '),
        WordPair(word: 'dune', translation: 'пер', rowId: ''),
      ];
      final got = await loadGapQuestions(words, const [], api);
      expect(api.calls.single.$2.map((x) => x.rowId), ['r0', 'r1', 'r2']);
      expect(got.keys, ['r2']);
    });

    test('AC-24: a LearnApiException goes up unchanged', () async {
      final e = LearnApiException(LearnApiError.dayLimit, 'cap');
      await expectLater(loadGapQuestions([w(0)], const [], _Api(const {}, e)), throwsA(same(e)));
    });

    test('AC-30: the same input gives the same questions', () async {
      final words = [w(0, word: 'walk'), w(1, word: 'tide')];
      Future<List<String>> run() async => [
            for (final q in (await loadGapQuestions(
                    words, const [], _Api({'walk': 'We walk to the station now.', 'tide': 'The tide comes in so fast.'})))
                .values)
              '${q.rowId}|${q.sentence}|${q.masked}|${q.cue}|${q.answer}',
          ];
      expect(await run(), await run());
    });

    test('no words, no call', () async {
      final api = _Api();
      expect(await loadGapQuestions(const [], const [], api), isEmpty);
      expect(api.calls, isEmpty);
    });
  });

  group('GapPrompt', () {
    GapQuestion q() => gapFromText(w(0, word: 'harbour', translation: 'порт'), 'The harbour is closed tonight.', GapSource.dialogue)!;

    testWidgets('S-45: masked sentence and cue; revealed shows the sentence with the word in bold', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(MaterialApp(home: _Host(key: key, question: q())));
      expect(find.text('The ___ is closed tonight.'), findsOneWidget);
      expect(find.text('порт'), findsOneWidget);
      expect(find.textContaining('harbour'), findsNothing);
      key.currentState!.reveal();
      await tester.pump();
      final rich = tester.widget<Text>(find.byKey(const ValueKey('gap-sentence')));
      final span = rich.textSpan! as TextSpan;
      expect(span.toPlainText(), 'The harbour is closed tonight.');
      final bold = span.children!.whereType<TextSpan>().where((s) => s.style?.fontWeight == FontWeight.bold);
      expect(bold.single.text, 'harbour');
      expect(find.text('порт'), findsOneWidget);
    });

    testWidgets('S-45: the exam answer field has no hint, no second try and only Skip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TypedAnswerField(
              key: const ValueKey('gap-r0'), expected: 'harbour', mode: TypedAnswerMode.exam, onSubmit: (_) {}),
        ),
      ));
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Show answer'), findsNothing);
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.question});
  final GapQuestion question;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool revealed = false;
  void reveal() => setState(() => revealed = true);

  @override
  Widget build(BuildContext context) => Scaffold(body: GapPrompt(widget.question, revealed: revealed));
}
