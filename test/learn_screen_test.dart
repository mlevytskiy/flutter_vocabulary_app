import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// learn-part-step-1 T6 (AC-04, AC-06, AC-07, AC-13): the app's learn page.
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

Session _session(int filled, {int bare = 0}) => Session.create()
  ..words = [
    for (var i = 0; i < filled; i++)
      WordPair(word: 'w$i', translation: 't$i'),
    for (var i = 0; i < bare; i++) WordPair(word: 'bare$i'),
  ];

void main() {
  final current = _session(1, bare: 2);
  final history = _session(3);

  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {String? sessionId}) async {
    // Tall enough that the whole list is built, so tiles can be counted.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(current)),
      sessionByIdProvider(history.sessionId)
          .overrideWith((ref) async => history),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      await container.read(sessionByIdProvider(history.sessionId).future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: LearnScreen(sessionId: sessionId)),
    ));
    await tester.pump();
  }

  final start = find.widgetWithText(ElevatedButton, 'Start');
  const hint = 'Pick at least one exercise';
  final mnemonic = find.widgetWithText(CheckboxListTile, 'Mnemonic story');


  testWidgets('AC-04: title, count, steps, eleven tiles in plan order',
      (tester) async {
    await pump(tester);
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);
    expect(find.text('1 word'), findsOneWidget); // bare rows not counted

    final seen = [
      for (final w in tester.widgetList<Text>(find.descendant(
          of: find.byType(ListView), matching: find.byType(Text))))
        w.data
    ];
    final order = [
      'Step 1', ...exercises.where((e) => e.stage == 1).map((e) => e.name),
      'Step 2', ...exercises.where((e) => e.stage == 2).map((e) => e.name),
      'Step 3', ...exercises.where((e) => e.stage == 3).map((e) => e.name),
    ];
    expect(seen.where(order.contains).toList(), order);
    expect(find.byType(CheckboxListTile), findsNWidgets(11));
    expect(exercises.length, 11);
  });

  testWidgets('default: nothing ticked, Start disabled, hint shown',
      (tester) async {
    await pump(tester);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    expect(find.text(hint), findsOneWidget);
    for (final t in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile))) {
      expect(t.value, isFalse);
    }
    await tester.tap(start, warnIfMissed: false);
    await tester.pump();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('AC-06: only Mnemonic is enabled; coming-soon taps change nothing',
      (tester) async {
    await pump(tester);
    final tiles =
        tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tiles.where((t) => t.enabled ?? true).length, 1);
    expect(find.text('Coming soon'), findsNWidgets(10));
    final soon = find.widgetWithText(CheckboxListTile, 'Translate sentences');
    await tester.tap(find.descendant(of: soon, matching: find.byType(Checkbox)));
    await tester.tap(find.descendant(of: soon, matching: find.text('Translate sentences')));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    expect(find.text(hint), findsOneWidget);
    for (final t in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile))) {
      expect(t.value, isFalse);
    }
  });

  testWidgets('AC-07: tick enables Start and hides the hint; untick reverts',
      (tester) async {
    await pump(tester);
    await tester.tap(mnemonic);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(mnemonic).value, isTrue);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);
    expect(find.text(hint), findsNothing);
    await tester.tap(mnemonic);
    await tester.pump();
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('AC-13: a History sessionId shows its count, current untouched',
      (tester) async {
    await pump(tester, sessionId: history.sessionId);
    expect(find.text('3 words'), findsOneWidget);
    expect(container.read(wordInputNotifierProvider).value!.sessionId,
        current.sessionId);
  });

  test('LearnRoute sits under the table and carries the optional sessionId', () {
    expect(const LearnRoute().location, '/table/learn');
    expect(const LearnRoute(sessionId: 'abc').location,
        '/table/learn?session-id=abc');
  });
}
