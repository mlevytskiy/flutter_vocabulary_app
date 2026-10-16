import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/history/history_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// collections-screen T20 (SCR-11, AC-28, AC-33): History rows show the name
/// with "N words" beside it, the date below and the "current" mark.

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

WordCollection _make(String id, String? name, int words, DateTime at) =>
    WordCollection.create()
      ..collectionId = id
      ..name = name
      ..updatedAt = at
      ..words = [for (var i = 0; i < words; i++) WordPair(word: 'w$i', translation: 't$i')];

void main() {
  final named = _make('a-1', 'Phrasal verbs', 32, DateTime(2026, 10, 16, 14, 30));
  final unnamed = _make('b-1', null, 1, DateTime(2026, 10, 15, 19, 5));

  Future<void> pump(WidgetTester tester, List<WordCollection> list, WordCollection current) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nonEmptyCollectionsProvider.overrideWith((ref) => Stream.value(list)),
        wordInputNotifierProvider.overrideWith(() => _FakeInput(current)),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a row shows the name, "N words" beside it, the date below, and current',
      (tester) async {
    await pump(tester, [named, unnamed], named);
    expect(find.text('Phrasal verbs'), findsOneWidget);
    expect(find.text('32 words'), findsOneWidget);
    expect(find.text('16.10.2026 14:30'), findsOneWidget);
    expect(find.text('current'), findsOneWidget);
    // Name above the date, "32 words" on the same line as the name.
    expect(tester.getTopLeft(find.text('Phrasal verbs')).dy,
        lessThan(tester.getTopLeft(find.text('16.10.2026 14:30')).dy));
    expect((tester.getCenter(find.text('32 words')).dy - tester.getCenter(find.text('Phrasal verbs')).dy).abs(),
        lessThan(4));
  });

  testWidgets('a collection with no name yet shows the name made from its moment',
      (tester) async {
    await pump(tester, [unnamed], named);
    expect(find.text('1 word'), findsOneWidget);
    expect(find.text(defaultCollectionName(unnamed.updatedAt)), findsWidgets);
  });

  testWidgets('says "No collections yet" when the list is empty', (tester) async {
    await pump(tester, const [], named);
    expect(find.text('No collections yet'), findsOneWidget);
    expect(find.text('No sessions yet'), findsNothing);
  });
}
