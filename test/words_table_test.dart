import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// definition-mode T14: the words table lists every filled row and shows the
/// columns the word detail mode shows (spec AC-12, AC-14).
void main() {
  final session = Session.create()
    ..words = [
      WordPair(word: 'claim', translation: 'заява', definition: 'to ask for'),
      WordPair(word: 'gated', definition: 'having a gate'),
      WordPair(word: 'curse', translation: 'прокляття'),
      WordPair(word: 'orphan'),
    ];

  Future<void> pumpTable(WidgetTester tester, WordDetailMode mode) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': mode.name});
    final container = ProviderContainer(overrides: [
      sessionByIdProvider(session.sessionId)
          .overrideWith((ref) async => session),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(sessionByIdProvider(session.sessionId).future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: WordsTableScreen(sessionId: session.sessionId)),
    ));
    await tester.pump();
  }

  List<String> headers(WidgetTester tester) => tester
      .widget<DataTable>(find.byType(DataTable))
      .columns
      .map((c) => ((c.label as Text).data)!)
      .toList();

  testWidgets('translation mode: word + translation, every filled row',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation);
    expect(headers(tester), ['#', 'Word', 'Translation']);
    expect(find.text('gated'), findsOneWidget); // definition-only row listed
    expect(find.text('orphan'), findsNothing); // a bare word is not filled
    expect(find.text('to ask for'), findsNothing);
  });

  testWidgets('definition mode: word + definition', (tester) async {
    await pumpTable(tester, WordDetailMode.definition);
    expect(headers(tester), ['#', 'Word', 'Definition']);
    expect(find.text('having a gate'), findsOneWidget);
    expect(find.text('заява'), findsNothing);
    expect(find.text('curse'), findsOneWidget); // translation-only row listed
  });

  testWidgets('both: all three columns', (tester) async {
    await pumpTable(tester, WordDetailMode.both);
    expect(headers(tester), ['#', 'Word', 'Translation', 'Definition']);
    expect(find.text('заява'), findsOneWidget);
    expect(find.text('to ask for'), findsOneWidget);
  });
}
