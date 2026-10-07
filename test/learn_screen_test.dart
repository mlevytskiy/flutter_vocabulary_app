import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/widgets/step_progress.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';
import 'fake_story_groups.dart';

/// learn-part-step-1 T6 (AC-04, AC-06, AC-07, AC-13): the app's learn page.
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

Session _session(int filled, {int bare = 0}) => Session.create()
  ..words = [
    for (var i = 0; i < filled; i++) WordPair(word: 'w$i', translation: 't$i'),
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
      ...fakeGroupOverrides(),
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

  // The top bar's Start; the last step's Start is [pagerButton].
  final start = find.descendant(
      of: find.byType(AppBar), matching: find.bySubtype<ElevatedButton>());
  final pagerButton = find.byKey(const ValueKey('pager-button'));
  const hint = 'Pick at least one exercise';
  final mnemonic = find.widgetWithText(CheckboxListTile, 'Mnemonic story');

  /// The next card peeks in beside the current one, so finders are scoped
  /// to one step's card.
  Finder card(int stage) => find.byKey(ValueKey('step-$stage'));
  Finder inCard(int stage, Finder f) =>
      find.descendant(of: card(stage), matching: f);

  /// Taps Next and returns once the next card has settled.
  Future<void> next(WidgetTester tester) async {
    await tester
        .tap(find.descendant(of: pagerButton, matching: find.text('Next')));
    await tester.pumpAndSettle();
  }

  int currentStep(WidgetTester tester) =>
      tester.widget<StepProgress>(find.byType(StepProgress)).current + 1;

  Future<void> tapStep(WidgetTester tester, int stage) async {
    await tester.tap(find.descendant(
        of: find.byType(StepProgress), matching: find.text('Step $stage')));
    await tester.pumpAndSettle();
  }

  List<String?> cardTiles(WidgetTester tester, int stage) => [
        for (final t in tester.widgetList<CheckboxListTile>(
            inCard(stage, find.byType(CheckboxListTile))))
          (t.title as Text).data,
      ];

  testWidgets('AC-04: title, step progress, one card per step in plan order',
      (tester) async {
    await pump(tester);
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);
    expect(exercises.length, 11);
    for (final stage in const [1, 2, 3]) {
      expect(find.text('Step $stage'), findsOneWidget); // in the progress
      expect(currentStep(tester), stage);
      expect(cardTiles(tester, stage),
          exercises.where((e) => e.stage == stage).map((e) => e.name));
      // Next until the last step, which has Start instead.
      expect(
          find.descendant(
              of: pagerButton,
              matching: find.text(stage < 3 ? 'Next' : 'Start')),
          findsOneWidget);
      // The button is in front of the pager, not on a page.
      expect(inCard(stage, pagerButton), findsNothing);
      if (stage < 3) await next(tester);
    }
  });

  testWidgets('the last step\'s Start follows the ticks; steps are tappable',
      (tester) async {
    await pump(tester);
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
    await tapStep(tester, 3);
    expect(currentStep(tester), 3);
    expect(tester.widget<ElevatedButton>(pagerButton).onPressed, isNotNull);
    await tapStep(tester, 1);
    expect(currentStep(tester), 1);
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
    await tapStep(tester, 3);
    expect(tester.widget<ElevatedButton>(pagerButton).onPressed, isNull);
  });

  testWidgets('swiping changes the card and the step title', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(currentStep(tester), 2);
    await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(currentStep(tester), 1);
  });

  testWidgets('a tick survives moving to another card and back',
      (tester) async {
    await pump(tester);
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
    await next(tester);
    await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(mnemonic).value, isTrue);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);
  });

  testWidgets('default: nothing ticked, Start disabled, hint shown',
      (tester) async {
    await pump(tester);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    expect(find.text(hint), findsOneWidget);
    for (final t
        in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(t.value, isFalse);
    }
    await tester.tap(start, warnIfMissed: false);
    await tester.pump();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('hint is a sticky SnackBar that OK closes', (tester) async {
    await pump(tester);
    final bar = find.widgetWithText(SnackBar, hint);
    expect(bar, findsOneWidget);
    await tester.pump(const Duration(hours: 1));
    expect(bar, findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, 'OK'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });

  testWidgets(
      'on a phone: 280 x 350 card in the middle, progress centred just above '
      'it, shadow room below, button on the card\'s corner, next card peeking',
      (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    final current = tester.getRect(inCard(1, find.byType(Card)));
    expect(current.size, const Size(280, 350));
    expect(current.center.dx, closeTo(200, 0.5));
    final progress = tester.getRect(find.byType(StepProgress));
    expect(progress.width, 280);
    expect(progress.center.dx, closeTo(200, 0.5));
    expect(current.top - progress.bottom, closeTo(8, 0.5));
    // The pager leaves 8 dp under the card so its shadow is not cut off.
    expect(tester.getRect(find.byType(PageView)).bottom - current.bottom,
        closeTo(8, 0.5));
    final button = tester.getRect(pagerButton);
    expect(current.right - button.right, closeTo(12, 0.5));
    expect(current.bottom - button.bottom, closeTo(12, 0.5));
    // The next card's edge shows at the right, 16 dp after the current one.
    final peek = tester.getRect(inCard(2, find.byType(Card)));
    expect(peek.left, closeTo(current.right + 16, 0.5));
    expect(peek.left, lessThan(400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card does not move when the hint closes', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    final before = tester.getRect(inCard(1, find.byType(Card)));
    await tester.tap(find.widgetWithText(SnackBarAction, 'OK'));
    await tester.pumpAndSettle();
    expect(tester.getRect(inCard(1, find.byType(Card))), before);
  });

  testWidgets('ticking an exercise closes the hint SnackBar', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SnackBar, hint), findsOneWidget);
  });

  testWidgets(
      'AC-06: only Mnemonic is enabled; coming-soon taps change nothing',
      (tester) async {
    await pump(tester);
    final tiles =
        tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tiles.where((t) => t.enabled ?? true).length, 1);
    expect(inCard(1, find.text('Coming soon')), findsNWidgets(3));
    await next(tester);
    await next(tester);
    final soon = find.widgetWithText(CheckboxListTile, 'Translate sentences');
    await tester
        .tap(find.descendant(of: soon, matching: find.byType(Checkbox)));
    await tester.tap(
        find.descendant(of: soon, matching: find.text('Translate sentences')));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    expect(find.text(hint), findsOneWidget);
    for (final t
        in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
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

  testWidgets('AC-13: a History sessionId leaves the current session alone',
      (tester) async {
    await pump(tester, sessionId: history.sessionId);
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(container.read(wordInputNotifierProvider).value!.sessionId,
        current.sessionId);
  });

  test('LearnRoute sits under the table and carries the optional sessionId',
      () {
    expect(const LearnRoute().location, '/table/learn');
    expect(const LearnRoute(sessionId: 'abc').location,
        '/table/learn?session-id=abc');
  });
}
