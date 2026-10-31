import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learner_profile_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LearnerProfileStore store;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [learnerProfileStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LearnerProfileSection()))),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<LearnerProfile> stored(WidgetTester tester) async =>
      (await tester.runAsync(store.read))!;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = LearnerProfileStore();
  });

  testWidgets('AC-11 shows the note and Not set for each empty field', (tester) async {
    await open(tester);
    expect(find.text('Used only to pick talk topics'), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(3));
    expect(find.text('English level'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Daily context'), findsOneWidget);
  });

  testWidgets('AC-11 shows saved values', (tester) async {
    SharedPreferences.setMockInitialValues({
      LearnerProfileStore.key: '{"v":1,"level":"Advanced","goal":"Make friends","daily":"Working"}',
    });
    await open(tester);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Make friends'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);
  });

  testWidgets('AC-11 a tap on a level saves it', (tester) async {
    await open(tester);
    await tester.tap(find.text('English level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper-intermediate'));
    await tester.pumpAndSettle();
    expect(find.text('Upper-intermediate'), findsOneWidget);
    expect((await stored(tester)).level, 'Upper-intermediate');
  });

  testWidgets('AC-11 a tap on a goal saves it', (tester) async {
    await open(tester);
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel confidently'));
    await tester.pumpAndSettle();
    expect((await stored(tester)).goal, 'Travel confidently');
  });

  testWidgets('AC-04 own words: Send disabled when empty or over 80, with a hint', (tester) async {
    await open(tester);
    await tester.tap(find.text('Daily context'));
    await tester.pumpAndSettle();
    VoidCallback? send() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Send')).onPressed;
    expect(send(), isNull);
    await tester.enterText(find.byType(TextField), 'x' * 81);
    await tester.pump();
    expect(send(), isNull);
    expect(find.text('Keep it under 80 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  night shifts at a hospital ');
    await tester.pump();
    expect(send(), isNotNull);
    expect(find.text('Keep it under 80 characters'), findsNothing);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect((await stored(tester)).daily, 'night shifts at a hospital');
    expect(find.text('night shifts at a hospital'), findsOneWidget);
  });

  testWidgets('AC-11 clearing a field shows Not set and keeps round and counters', (tester) async {
    await tester.runAsync(() async {
      await store.setLevel('Beginner');
      await store.setGoal('Make friends');
      await store.setRound(['daily']);
      await store.setGrammarCounter(4);
    });
    await open(tester);
    await tester.tap(find.byTooltip('Clear English level'));
    await tester.pumpAndSettle();
    final p = await stored(tester);
    expect(p.level, isNull);
    expect(p.goal, 'Make friends');
    expect(p.round, ['daily']);
    expect(p.grammarCounter, 4);
    expect(find.text('Not set'), findsNWidgets(2));
    expect(find.byTooltip('Clear English level'), findsNothing);
  });
}
