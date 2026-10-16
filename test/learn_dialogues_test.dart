import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/widgets/group_pager.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'fake_story_groups.dart';

/// get-words-from-subtitles-improvment T21: "Dialogs from movie" and the
/// dialogue groups on the learn page (SCR-06; AC-13, AC-15, AC-16, AC-24,
/// AC-25).

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

const dialogueLine = 'Your words are grouped by the dialogues from the film. '
    'Please select one group to learn.';
const topicLine =
    'We grouped your words into sets of up to 19 words. Please select one group to learn.';

WordPair row(int i) => WordPair(word: 'word$i', translation: 'tr$i', rowId: 'r$i');

WordGroup makeGroup(String id, String name, List<int> rows, {String? dialogueId}) =>
    WordGroup()
      ..id = id
      ..name = name
      ..rowIds = [for (final i in rows) 'r$i']
      ..dialogueId = dialogueId;

void main() {
  final withDialogues = WordCollection.create()
    ..words = [for (var i = 1; i <= 12; i++) row(i)]
    ..dialogues = [
      FilmDialogue()
        ..id = 'd1'
        ..lines = ['Where is word1?']
        ..wordRowIds = ['r1'],
      FilmDialogue()
        ..id = 'd2'
        ..lines = ['Fine, word2.']
        ..wordRowIds = ['r2'],
    ];
  final noDialogues = WordCollection.create()..words = [for (var i = 1; i <= 5; i++) row(i)];

  final d1 = makeGroup('dialogue-d1', 'Where is word1?', [1], dialogueId: 'd1');
  final d2 = makeGroup('dialogue-d2', 'Fine, word2.', [2], dialogueId: 'd2');
  final food = makeGroup('food', 'Food', [3, 4, 5])..storyRunId = 'run-1';
  final other = makeGroup('other', otherWordsName, [6, 7, 8, 9, 10, 11, 12]);

  late FakeGroups groups;

  Future<void> pumpScreen(WidgetTester tester, WordCollection collection, WordGroupsState state) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    groups = FakeGroups(state);
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(collection)),
      wordGroupsNotifierProvider(null).overrideWith(() => groups),
      storyRunTrackerProvider.overrideWith(() => FakeTracker(const StoryTrackerState())),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(wordInputNotifierProvider.future));

    Widget stub(String text) => Scaffold(appBar: AppBar(), body: Text(text));
    final router = GoRouter(
      initialLocation: '/table/learn',
      routes: [
        GoRoute(
          path: '/table/learn',
          builder: (context, state) => const LearnScreen(),
          routes: [
            GoRoute(
              path: 'story',
              builder: (context, state) => stub('story:${state.uri.queryParameters['group-id']}'),
            ),
            GoRoute(
              path: 'dialogue',
              builder: (context, state) => stub('dialogue:${state.uri.queryParameters['group-id']}'),
            ),
            GoRoute(
              path: 'soon',
              builder: (context, state) => stub('soon:${state.uri.queryParameters['exercise']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  final start = find.descendant(of: find.byType(AppBar), matching: find.bySubtype<ElevatedButton>());
  final mnemonic = find.widgetWithText(CheckboxListTile, 'Mnemonic story');
  final dialogs = find.widgetWithText(CheckboxListTile, 'Dialogs from movie');
  bool startEnabled(WidgetTester tester) => tester.widget<ElevatedButton>(start).onPressed != null;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('without dialogues it is greyed with "Needs dialogues from subtitles" (AC-16)', (tester) async {
    await pumpScreen(tester, noDialogues,
        WordGroupsState(groups: [makeGroup('all', allWordsName, [1, 2, 3, 4, 5])], selectedGroupId: 'all'));

    final tile = tester.widget<CheckboxListTile>(dialogs);
    expect(tile.enabled, isFalse);
    expect(find.descendant(of: dialogs, matching: find.text('Needs dialogues from subtitles')), findsOneWidget);
    expect(find.byType(GroupPager), findsNothing, reason: 'groups as before');
    await tap(tester, mnemonic);
    expect(startEnabled(tester), isTrue);
  });

  testWidgets('with dialogues: tickable, the dialogue line, dialogue cards then "Other words" then topics (AC-13)',
      (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [food, d1, other, d2], selectedGroupId: 'dialogue-d1'));

    expect(tester.widget<CheckboxListTile>(dialogs).enabled, isTrue);
    expect(find.text(dialogueLine), findsOneWidget);
    expect(find.text(topicLine), findsNothing);
    final pager = tester.widget<GroupPager>(find.byType(GroupPager));
    expect(pager.groups.map((g) => g.id), ['dialogue-d1', 'dialogue-d2', 'other', 'food']);
  });

  testWidgets('one dialogue group alone still shows the pager (AC-25)', (tester) async {
    await pumpScreen(tester, withDialogues, WordGroupsState(groups: [d1], selectedGroupId: 'dialogue-d1'));
    expect(find.byType(GroupPager), findsOneWidget);
    expect(find.text(dialogueLine), findsOneWidget);
  });

  testWidgets('selecting a dialogue group starts nothing (AC-24)', (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [d1, d2, other], selectedGroupId: 'dialogue-d1'));
    await tap(tester, find.byKey(const ValueKey('group-card-dialogue-d2')));
    expect(groups.selected, ['dialogue-d2']);
    expect(find.textContaining('story:'), findsNothing);
  });

  testWidgets('Dialogs from movie on "Other words" opens its mnemonic story (AC-13)', (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [d1, other], selectedGroupId: 'other'));
    await tap(tester, dialogs);
    expect(startEnabled(tester), isTrue);
    await tap(tester, start);
    expect(find.text('story:other'), findsOneWidget);
  });

  testWidgets('both ticked on "Other words" open its story once', (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [d1, other], selectedGroupId: 'other'));
    await tap(tester, mnemonic);
    await tap(tester, dialogs);
    await tap(tester, start);
    expect(find.text('story:other'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(find.textContaining('story:'), findsNothing);
  });

  testWidgets('Dialogs from movie on a dialogue group opens its dialogue (AC-13)', (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [d1, other], selectedGroupId: 'dialogue-d1'));
    await tap(tester, dialogs);
    await tap(tester, start);
    expect(find.text('dialogue:dialogue-d1'), findsOneWidget);
  });

  testWidgets('both ticked on a dialogue group: its story, then its dialogue, in list order (AC-13)',
      (tester) async {
    await pumpScreen(tester, withDialogues,
        WordGroupsState(groups: [d1, other], selectedGroupId: 'dialogue-d1'));
    await tap(tester, mnemonic);
    await tap(tester, dialogs);
    await tap(tester, start);
    expect(find.text('story:dialogue-d1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('dialogue:dialogue-d1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
  });

  testWidgets('Dialogs from movie needs a selected group', (tester) async {
    await pumpScreen(tester, withDialogues, WordGroupsState(groups: [d1, other]));
    await tap(tester, dialogs);
    expect(startEnabled(tester), isFalse);
  });
}
