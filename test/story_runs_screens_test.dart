import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/features/words_settings/story_run_screen.dart';
import 'package:flutter_vocabulary_app/features/words_settings/story_runs_screen.dart';
import 'package:flutter_vocabulary_app/features/words_settings/words_settings_screen.dart';

/// mnemonic-story T19 (AC-14, AC-15): the list of every story run, newest
/// first, and one run's details. Reads only what the app stored.

StoryStep _step(String role, String model,
        {String outcome = 'done',
        double? price,
        bool estimated = false,
        int? ms,
        String? text,
        int attempt = 1}) =>
    StoryStep()
      ..role = role
      ..attempt = attempt
      ..modelId = model
      ..modelName = model
      ..outcome = outcome
      ..priceUsd = price
      ..priceEstimated = estimated
      ..ms = ms
      ..text = text;

StoryRun _run(String id, String group, DateTime at, List<StoryStep> steps,
        {String outcome = 'done'}) =>
    StoryRun()
      ..runId = id
      ..sessionId = 's'
      ..groupId = 'g-$id'
      ..groupName = group
      ..startedAt = at
      ..models = ['Writer', 'Prompter', 'Painter']
      ..steps = steps
      ..outcome = outcome;

final _finished = _run(
  'r-new',
  'Kitchen',
  DateTime(2026, 10, 7, 9, 30),
  [
    _step('story', 'Writer', price: 0.01, ms: 4000, text: 'A cat in a kitchen.'),
    _step('prompt', 'Prompter', price: 0.002, ms: 2000, text: 'A cat, cartoon'),
    _step('picture', 'Painter', price: 0.02, ms: 9000),
  ],
);

// Stopped at the picture: one failed try with an estimated price.
final _stopped = _run(
  'r-mid',
  'Travel',
  DateTime(2026, 10, 5),
  [
    _step('story', 'Writer', price: 0.01, ms: 3000, text: 'A trip.'),
    _step('prompt', 'Prompter', price: 0.002, ms: 1500, text: 'A trip, ink'),
    _step('picture', 'Painter',
        outcome: 'failed', price: 0.02, estimated: true, ms: 120000),
  ],
  outcome: 'failed',
);

// Never started: nothing was taken from the allowance.
final _notStarted =
    _run('r-none', 'Old group', DateTime(2026, 10, 1), [], outcome: 'failed');

void main() {
  Future<void> pumpList(WidgetTester tester, List<StoryRun> runs,
      {void Function(String)? onOpen}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [storyRunsProvider.overrideWith((ref) => Stream.value(runs))],
      child: MaterialApp(home: StoryRunsScreen(onOpenRun: onOpen ?? (_) {})),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpDetails(WidgetTester tester, List<StoryRun> runs, String id) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [storyRunsProvider.overrideWith((ref) => Stream.value(runs))],
      child: MaterialApp(home: StoryRunScreen(runId: id)),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('says "No story runs yet" when there are none', (tester) async {
    await pumpList(tester, const []);
    expect(find.text('No story runs yet'), findsOneWidget);
  });

  testWidgets('lists runs newest first even when stored out of order', (tester) async {
    await pumpList(tester, [_notStarted, _finished, _stopped]);
    double top(String id) => tester.getTopLeft(find.byKey(ValueKey('run-$id'))).dy;
    expect(top('r-new'), lessThan(top('r-mid')));
    expect(top('r-mid'), lessThan(top('r-none')));
  });

  testWidgets('a row has the group, date, the three AIs, and the sums of price and time',
      (tester) async {
    await pumpList(tester, [_finished]);
    final row = find.byKey(const ValueKey('run-r-new'));
    Finder inRow(String t) => find.descendant(of: row, matching: find.text(t));
    expect(inRow('Kitchen'), findsOneWidget);
    expect(inRow('7 Oct 2026'), findsOneWidget);
    expect(inRow('Writer · Prompter · Painter'), findsOneWidget);
    // 0.01 + 0.002 + 0.02 = 0.032; 4 + 2 + 9 = 15 s.
    expect(inRow(r'$0.032 · 15 s'), findsOneWidget);
    expect(inRow('Finished'), findsOneWidget);
  });

  testWidgets('a run that stopped is listed with where it stopped and "≈" for estimates',
      (tester) async {
    await pumpList(tester, [_stopped]);
    final row = find.byKey(const ValueKey('run-r-mid'));
    Finder inRow(String t) => find.descendant(of: row, matching: find.text(t));
    expect(inRow('Stopped at the picture'), findsOneWidget);
    // 0.01 + 0.002 + 0.02 (estimated) = 0.032; 3 + 1.5 + 120 = 124.5 s.
    expect(inRow(r'≈ $0.032 · 2 min 5 s'), findsOneWidget);
  });

  testWidgets('a run that never started is labelled, not hidden', (tester) async {
    await pumpList(tester, [_notStarted]);
    final row = find.byKey(const ValueKey('run-r-none'));
    expect(find.descendant(of: row, matching: find.text('Old group')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Not started — no cost')),
        findsOneWidget);
  });

  testWidgets('a running run says so', (tester) async {
    final running = _run('r-go', 'Now', DateTime(2026, 10, 8),
        [_step('story', 'Writer', price: 0.01, ms: 1000, text: 'x')],
        outcome: 'running');
    await pumpList(tester, [running]);
    expect(find.text('Still running'), findsOneWidget);
  });

  testWidgets('tapping a run opens it', (tester) async {
    String? opened;
    await pumpList(tester, [_finished], onOpen: (id) => opened = id);
    await tester.tap(find.byKey(const ValueKey('run-r-new')));
    expect(opened, 'r-new');
  });

  testWidgets('details show each step with its AI, result, price and time',
      (tester) async {
    await pumpDetails(tester, [_finished], 'r-new');
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('A cat in a kitchen.'), findsOneWidget);
    expect(find.text('A cat, cartoon'), findsOneWidget);
    final story = find.byKey(const ValueKey('step-story-1'));
    expect(find.descendant(of: story, matching: find.text('Story writer: Writer')),
        findsOneWidget);
    expect(find.descendant(of: story, matching: find.text(r'$0.01 · 4 s')), findsOneWidget);
    final pic = find.byKey(const ValueKey('step-picture-1'));
    expect(find.descendant(of: pic, matching: find.text('Picture maker: Painter')),
        findsOneWidget);
    expect(find.descendant(of: pic, matching: find.text(r'$0.02 · 9 s')), findsOneWidget);
  });

  testWidgets('details keep failed attempts and mark estimated prices with "≈"',
      (tester) async {
    final run = _run('r-try', 'Try', DateTime(2026, 10, 6), [
      _step('story', 'Writer', price: 0.01, ms: 3000, text: 'S'),
      _step('prompt', 'Prompter', price: 0.002, ms: 1000, text: 'P'),
      _step('picture', 'Painter',
          outcome: 'failed', price: 0.02, estimated: true, ms: 120000),
      _step('picture', 'Painter', price: 0.02, ms: 8000, attempt: 2),
    ]);
    await pumpDetails(tester, [run], 'r-try');
    final failed = find.byKey(const ValueKey('step-picture-1'));
    expect(find.descendant(of: failed, matching: find.text('Failed')), findsOneWidget);
    expect(find.descendant(of: failed, matching: find.text(r'≈ $0.02 · 2 min')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('step-picture-2')), findsOneWidget);
  });

  testWidgets('a failed story keeps its text and the words it left out', (tester) async {
    final run = _run(
        'r-miss',
        'Miss',
        DateTime(2026, 10, 6),
        [
          _step('story', 'Writer', outcome: 'failed', price: 0.01, ms: 2000, text: 'Half.')
            ..missedWords = ['apple', 'pear'],
        ],
        outcome: 'failed');
    await pumpDetails(tester, [run], 'r-miss');
    expect(find.text('Half.'), findsOneWidget);
    expect(find.text('Left out: apple, pear'), findsOneWidget);
  });

  testWidgets('details of an unknown run say it is not there', (tester) async {
    await pumpDetails(tester, [_finished], 'nope');
    expect(find.text('This story run is not on this phone'), findsOneWidget);
  });
}
