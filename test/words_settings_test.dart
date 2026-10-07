import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/offered_ai.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_settings/words_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// mnemonic-story T18 (AC-12, AC-13): Words settings shows the three AI
/// choices with prices, cheapest first (owner-requested addition to AC-12),
/// keeps the choice, and says when a chosen AI is no longer available.

// Deliberately not in price order.
const _opus = OfferedAi(
  id: 'claude-opus-5-5',
  name: 'Opus 5.5',
  provider: 'anthropic',
  role: 'text',
  inputUsdPerMTok: 5,
  outputUsdPerMTok: 25,
  estimate15Usd: 0.04,
);
const _sonnet = OfferedAi(
  id: 'claude-sonnet-5-5',
  name: 'Sonnet 5.5',
  provider: 'anthropic',
  role: 'text',
  inputUsdPerMTok: 2,
  outputUsdPerMTok: 10,
  estimate15Usd: 0.008,
);
const _deepseek = OfferedAi(
  id: 'deepseek-v4.1-flash',
  name: 'DeepSeek V4.1 Flash',
  provider: 'zen',
  role: 'text',
  inputUsdPerMTok: 0.3,
  outputUsdPerMTok: 1.2,
  estimate15Usd: 0.001,
);
const _higgs = OfferedAi(
  id: 'higgsfield-soul',
  name: 'Higgsfield Soul',
  provider: 'higgsfield',
  role: 'picture',
  usdPerPicture: 0.09,
  approx: true,
);
const _grok = OfferedAi(
  id: 'grok-imagine-image',
  name: 'Grok Imagine',
  provider: 'xai',
  role: 'picture',
  usdPerPicture: 0.02,
);
const _grokQuality = OfferedAi(
  id: 'grok-imagine-image-quality',
  name: 'Grok Imagine Quality',
  provider: 'xai',
  role: 'picture',
  usdPerPicture: 0.05,
);

const _offered = OfferedAiList(
  pricesAsOf: '2026-10-07',
  defaults: AiChoice(
      story: 'claude-sonnet-5-5',
      prompt: 'claude-sonnet-5-5',
      picture: 'grok-imagine-image'),
  models: [_opus, _higgs, _sonnet, _grokQuality, _deepseek, _grok],
);

StoryStep _step(String role, String modelId, double? price,
        {String outcome = 'done'}) =>
    StoryStep()
      ..role = role
      ..modelId = modelId
      ..outcome = outcome
      ..priceUsd = price;

StoryRun _run(String id, List<StoryStep> steps) => StoryRun()
  ..runId = id
  ..sessionId = 's'
  ..groupId = 'g'
  ..groupName = 'All words'
  ..startedAt = DateTime(2026, 10, 7)
  ..steps = steps;

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

void main() {
  ProviderContainer? last;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    List<StoryRun> runs = const [],
    OfferedAiList offered = _offered,
    ProviderContainer? container,
    VoidCallback? onStoryRuns,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    // Tall enough for all three choices at once (the list is built lazily).
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = container ??
        ProviderContainer(overrides: [
          offeredAisProvider.overrideWith((ref) async => offered),
          storyRunsProvider.overrideWith((ref) => Stream.value(runs)),
        ]);
    if (container == null) addTearDown(c.dispose);
    last = c;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: WordsSettingsScreen(onOpenStoryRuns: onStoryRuns)),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  Finder option(String role, String id) => find.byKey(ValueKey('ai-$role-$id'));

  double top(WidgetTester tester, String role, String id) =>
      tester.getTopLeft(option(role, id)).dy;

  testWidgets('shows the three choices with the defaults selected', (tester) async {
    await pump(tester);

    expect(find.text('Story writer'), findsOneWidget);
    expect(find.text('Picture prompt writer'), findsOneWidget);
    expect(find.text('Picture maker'), findsOneWidget);
    expect(option('story', 'claude-sonnet-5-5'), findsOneWidget);
    expect(option('prompt', 'claude-opus-5-5'), findsOneWidget);
    expect(option('picture', 'higgsfield-soul'), findsOneWidget);

    String selected(String role) => tester
        .widget<RadioGroup<String>>(find.byKey(ValueKey('ai-group-$role')))
        .groupValue!;
    expect(selected('story'), 'claude-sonnet-5-5');
    expect(selected('prompt'), 'claude-sonnet-5-5');
    expect(selected('picture'), 'grok-imagine-image');
  });

  testWidgets('options run from the cheapest to the most expensive (owner request)',
      (tester) async {
    await pump(tester);
    for (final role in ['story', 'prompt']) {
      expect(top(tester, role, 'deepseek-v4.1-flash'),
          lessThan(top(tester, role, 'claude-sonnet-5-5')));
      expect(top(tester, role, 'claude-sonnet-5-5'),
          lessThan(top(tester, role, 'claude-opus-5-5')));
    }
    expect(top(tester, 'picture', 'grok-imagine-image'),
        lessThan(top(tester, 'picture', 'grok-imagine-image-quality')));
    expect(top(tester, 'picture', 'grok-imagine-image-quality'),
        lessThan(top(tester, 'picture', 'higgsfield-soul')));
  });

  testWidgets('each option shows its list price under the name (owner request)',
      (tester) async {
    await pump(tester);
    expect(
        find.descendant(
            of: option('story', 'deepseek-v4.1-flash'),
            matching: find.text(r'List price: $0.30 in · $1.20 out per 1M tokens')),
        findsOneWidget);
    expect(
        find.descendant(
            of: option('story', 'claude-opus-5-5'),
            matching: find.text(r'List price: $5.00 in · $25.00 out per 1M tokens')),
        findsOneWidget);
    expect(
        find.descendant(
            of: option('picture', 'grok-imagine-image'),
            matching: find.text(r'List price: $0.02 per picture')),
        findsOneWidget);
    // An approximate picture price says so.
    expect(
        find.descendant(
            of: option('picture', 'higgsfield-soul'),
            matching: find.text(r'List price: ≈ $0.09 per picture')),
        findsOneWidget);
  });

  testWidgets('text AIs show an estimate until they have run (AC-12)',
      (tester) async {
    await pump(tester);
    expect(
        find.descendant(
            of: option('story', 'claude-sonnet-5-5'),
            matching: find.text(r'≈ $0.008 (estimate)')),
        findsOneWidget);
    expect(
        find.descendant(
            of: option('prompt', 'claude-opus-5-5'),
            matching: find.text(r'≈ $0.04 (estimate)')),
        findsOneWidget);
  });

  testWidgets('picture makers show their price per picture (AC-12)',
      (tester) async {
    await pump(tester);
    expect(
        find.descendant(
            of: option('picture', 'grok-imagine-image'),
            matching: find.text(r'$0.02 per picture')),
        findsOneWidget);
    expect(
        find.descendant(
            of: option('picture', 'higgsfield-soul'),
            matching: find.text(r'≈ $0.09 per picture')),
        findsOneWidget);
  });

  testWidgets('averages count finished steps per role and AI (AC-12)',
      (tester) async {
    await pump(tester, runs: [
      _run('a', [
        _step('story', 'claude-sonnet-5-5', 0.01),
        _step('prompt', 'claude-sonnet-5-5', 0.002),
      ]),
      _run('b', [
        _step('story', 'claude-sonnet-5-5', 0.02),
        _step('prompt', 'claude-sonnet-5-5', 0.004),
        // A failed step and a step without a price do not count.
        _step('story', 'claude-opus-5-5', 0.5, outcome: 'failed'),
        _step('prompt', 'claude-opus-5-5', null),
      ]),
    ]);

    // Story writer: two finished Sonnet steps averaging 0.015.
    expect(
        find.descendant(
            of: option('story', 'claude-sonnet-5-5'),
            matching: find.text(r'$0.015 average · 2 runs')),
        findsOneWidget);
    // Picture prompt writer is counted separately: 0.003.
    expect(
        find.descendant(
            of: option('prompt', 'claude-sonnet-5-5'),
            matching: find.text(r'$0.003 average · 2 runs')),
        findsOneWidget);
    // Opus never finished a step: still an estimate.
    expect(
        find.descendant(
            of: option('story', 'claude-opus-5-5'),
            matching: find.text(r'≈ $0.04 (estimate)')),
        findsOneWidget);
    // The list price stays under an average, too.
    expect(
        find.descendant(
            of: option('story', 'claude-sonnet-5-5'),
            matching: find.text(r'List price: $2.00 in · $10.00 out per 1M tokens')),
        findsOneWidget);
  });

  testWidgets('a saved AI that is no longer offered says so and falls back (AC-13)',
      (tester) async {
    await pump(tester, prefs: {
      'story_ai_story': 'gone-model',
      'story_ai_story_name': 'Gone Model',
      'story_ai_picture': 'claude-opus-5-5', // an id of the wrong role
      'story_ai_picture_name': 'Opus 5.5',
    });

    expect(find.text('Gone Model is no longer available'), findsOneWidget);
    expect(find.text('Opus 5.5 is no longer available'), findsOneWidget);
    expect(
        tester
            .widget<RadioGroup<String>>(find.byKey(const ValueKey('ai-group-story')))
            .groupValue,
        'claude-sonnet-5-5');
    expect(
        tester
            .widget<RadioGroup<String>>(find.byKey(const ValueKey('ai-group-picture')))
            .groupValue,
        'grok-imagine-image');
  });

  testWidgets('no message when every saved AI is still offered', (tester) async {
    await pump(tester, prefs: {
      'story_ai_story': 'claude-opus-5-5',
      'story_ai_story_name': 'Opus 5.5',
    });
    expect(find.textContaining('no longer available'), findsNothing);
  });

  testWidgets('a choice is saved and kept after the providers are rebuilt (AC-12)',
      (tester) async {
    await pump(tester);
    await tester.tap(option('prompt', 'claude-opus-5-5'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RadioGroup<String>>(find.byKey(const ValueKey('ai-group-prompt')))
            .groupValue,
        'claude-opus-5-5');
    expect(last!.read(aiChoiceProvider).ids[AiRole.prompt], 'claude-opus-5-5');

    // A fresh container reads what the first one stored in shared_preferences.
    await tester.pumpWidget(const SizedBox());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('story_ai_prompt'), 'claude-opus-5-5');
    final again = ProviderContainer(overrides: [
      offeredAisProvider.overrideWith((ref) async => _offered),
      storyRunsProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    addTearDown(again.dispose);
    await pump(tester, prefs: prefs.getKeys().fold<Map<String, Object>>({}, (m, k) {
      m[k] = prefs.get(k)!;
      return m;
    }), container: again);
    expect(
        tester
            .widget<RadioGroup<String>>(find.byKey(const ValueKey('ai-group-prompt')))
            .groupValue,
        'claude-opus-5-5');
    expect(
        tester
            .widget<RadioGroup<String>>(find.byKey(const ValueKey('ai-group-story')))
            .groupValue,
        'claude-sonnet-5-5');
  });

  testWidgets('has a Story runs entry', (tester) async {
    var opened = 0;
    await pump(tester, onStoryRuns: () => opened++);
    await tester.tap(find.text('Story runs'));
    expect(opened, 1);
  });

  group('the Words screen button', () {
    testWidgets('looks like the main screen\'s settings button and opens Words settings',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = Session.create()
        ..words = [WordPair(word: 'coffee', translation: 'кава')];
      final container = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
        offeredAisProvider.overrideWith((ref) async => _offered),
        storyRunsProvider.overrideWith((ref) => Stream.value(const [])),
      ]);
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(wordInputNotifierProvider.future));
      final router = GoRouter(initialLocation: '/table', routes: [
        GoRoute(
          path: '/table',
          builder: (context, state) => const WordsTableScreen(),
          routes: [
            GoRoute(
                path: 'settings',
                builder: (context, state) => const WordsSettingsScreen()),
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      final button = find.widgetWithIcon(FloatingActionButton, Icons.settings);
      expect(button, findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(button);
      expect(fab.tooltip, 'Settings');
      expect(fab.backgroundColor, const Color(0xff954ef3));
      expect(fab.shape, const CircleBorder());
      expect(tester.getBottomLeft(button).dx, lessThan(100));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(WordsSettingsScreen), findsOneWidget);
    });
  });
}
