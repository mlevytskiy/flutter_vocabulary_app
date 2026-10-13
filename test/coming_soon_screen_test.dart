import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/mnemonic_story/story_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';
import 'fake_story_groups.dart';

/// learn-part-step-1 T7 (AC-05, AC-05b): Start opens an exercise screen. Since
/// mnemonic-story T17 that is the story screen for Mnemonic story (AC-06).
class _FakeInput extends WordInputNotifier {
  @override
  Future<Session> build() async => Session.create()
    ..words = [WordPair(word: 'a', translation: 'b')];
}

void main() {
  final mnemonic = find.widgetWithText(CheckboxListTile, 'Mnemonic story');
  final start = find.descendant(
      of: find.byType(AppBar), matching: find.bySubtype<ElevatedButton>());
  const soon = 'Coming soon — this exercise is not ready yet.';

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      ...fakeGroupOverrides(),
      ...fakeGroupOverrides(),
      wordInputNotifierProvider.overrideWith(() => _FakeInput()),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(
        () => container.read(wordInputNotifierProvider.future));
    final router = GoRouter(initialLocation: '/table', routes: $appRoutes);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    unawaited(const LearnRoute().push<void>(router.routerDelegate
        .navigatorKey.currentContext!));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tickAndStart(WidgetTester tester) async {
    await tester.tap(mnemonic);
    await tester.pump();
    await tester.tap(start);
    // The story screen's spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void expectComingSoon() {
    expect(find.widgetWithText(AppBar, 'Learn'), findsNothing);
    expect(find.byType(StoryScreen), findsOneWidget);
    expect(find.text(soon), findsNothing);
  }

  testWidgets('AC-06: Start with Mnemonic story shows the story screen; back '
      'returns with Mnemonic story still ticked', (tester) async {
    await pump(tester);
    await tickAndStart(tester);
    expectComingSoon();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(mnemonic).value, isTrue);
  });

  testWidgets('AC-05: the back arrow returns with Mnemonic story still ticked',
      (tester) async {
    await pump(tester);
    await tickAndStart(tester);
    expectComingSoon();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(mnemonic).value, isTrue);
  });

  testWidgets('AC-05b: leaving to the Words screen and opening Learn again '
      'starts unticked', (tester) async {
    final router = await pump(tester);
    await tester.tap(mnemonic);
    await tester.pump();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsNothing);
    unawaited(const LearnRoute().push<void>(
        router.routerDelegate.navigatorKey.currentContext!));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(mnemonic).value, isFalse);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
  });

  test('ComingSoonRoute sits under learn at soon and carries the exercise id',
      () {
    expect(const ComingSoonRoute(exercise: 'mnemonic-story').location,
        '/table/learn/soon?exercise=mnemonic-story');
  });
}
