import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';
import 'fake_story_groups.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/widgets/group_pager.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// mnemonic-story T16 (AC-01 – AC-05, AC-19): the group line, the group pager
/// and the grouping messages on the learn page, and quiet grouping from the
/// Words screen.

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

const dayLimit = "Today's story limit is reached. Try again tomorrow.";
const groupLine =
    'We grouped your words into sets of up to 19 words. Please select one group to learn.';

WordPair row(int i) =>
    WordPair(word: 'word$i', translation: 'tr$i', rowId: 'r$i');

WordGroup makeGroup(String id, String name, List<int> rows) => WordGroup()
  ..id = id
  ..name = name
  ..rowIds = [for (final i in rows) 'r$i'];

void main() {
  final session = Session.create()
    ..words = [for (var i = 1; i <= 25; i++) row(i)];
  final food = makeGroup('g1', 'Food', [1, 2, 3, 4, 5, 6, 7]);
  final travel = makeGroup('g2', 'Travel', [8, 9, 10, 11, 12, 13, 14]);
  final home = makeGroup('g3', 'Home', [15, 16, 17, 18, 19, 20, 21]);
  final all = makeGroup('g0', 'All words', [1, 2, 3]);

  late FakeGroups groups;
  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester,
    WordGroupsState state, {
    Map<String, StoryStartRefusal> refusals = const {},
    Size size = const Size(800, 3000),
    Widget? home,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    groups = FakeGroups(state);
    container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      wordGroupsNotifierProvider(null).overrideWith(() => groups),
      storyRunTrackerProvider.overrideWith(
          () => FakeTracker(StoryTrackerState(refusals: refusals))),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home ?? const LearnScreen()),
    ));
    await tester.pumpAndSettle();
  }

  final start = find.descendant(
      of: find.byType(AppBar), matching: find.bySubtype<ElevatedButton>());
  final mnemonic = find.widgetWithText(CheckboxListTile, 'Mnemonic story');
  Finder cardOf(String id) => find.byKey(ValueKey('group-card-$id'));
  Finder tickIn(String id) => find.descendant(
      of: cardOf(id), matching: find.byIcon(Icons.check_circle));

  Future<void> tickMnemonic(WidgetTester tester) async {
    await tester.tap(mnemonic);
    await tester.pumpAndSettle();
  }

  bool startEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(start).onPressed != null;

  WordGroupsState several({String? selected = 'g2'}) => WordGroupsState(
        groups: [food, travel, home],
        selectedGroupId: selected,
      );

  group('learn page', () {
    testWidgets('AC-02: one group shows no line and no pager, Start works',
        (tester) async {
      await pumpScreen(
          tester, WordGroupsState(groups: [all], selectedGroupId: 'g0'));
      expect(find.text(groupLine), findsNothing);
      expect(find.byType(GroupPager), findsNothing);
      await tickMnemonic(tester);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('AC-01: several groups show the line and one card per group',
        (tester) async {
      await pumpScreen(tester, several());
      expect(find.text(groupLine), findsOneWidget);
      expect(find.byType(GroupPager), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      // each card names its group's words
      expect(
          find.descendant(
              of: cardOf('g1'), matching: find.textContaining('word1')),
          findsOneWidget);
      expect(
          find.descendant(
              of: cardOf('g2'), matching: find.textContaining('word8')),
          findsOneWidget);
    });

    testWidgets('AC-01: the remembered group is the selected one, only it',
        (tester) async {
      await pumpScreen(tester, several(selected: 'g2'));
      expect(tickIn('g2'), findsOneWidget);
      expect(tickIn('g1'), findsNothing);
      expect(tester.getSize(cardOf('g2')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('AC-01: tapping another card selects it and unselects the old',
        (tester) async {
      await pumpScreen(tester, several(selected: 'g2'));
      await tester.tap(cardOf('g1'));
      await tester.pumpAndSettle();
      expect(groups.selected, ['g1']);
      expect(tickIn('g1'), findsOneWidget);
      expect(tickIn('g2'), findsNothing);
    });

    testWidgets('AC-01: swiping the pager only browses', (tester) async {
      await pumpScreen(tester, several(selected: 'g1'),
          size: const Size(400, 800));
      expect(cardOf('g3').hitTestable(), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.fling(
            find.byType(GroupPager), const Offset(-300, 0), 1500);
        await tester.pumpAndSettle();
      }
      expect(groups.selected, isEmpty);
      expect(cardOf('g3').hitTestable(), findsOneWidget);
      expect(tickIn('g3'), findsNothing);
      // back at the start, the selection is still the first group's
      for (var i = 0; i < 2; i++) {
        await tester.fling(find.byType(GroupPager), const Offset(300, 0), 1500);
        await tester.pumpAndSettle();
      }
      expect(tickIn('g1'), findsOneWidget);
    });

    testWidgets('AC-03: opening the page asks for grouping', (tester) async {
      await pumpScreen(tester, several());
      expect(groups.ensured, 1);
    });

    testWidgets('AC-03: while grouping, "Grouping your words…" and no pager',
        (tester) async {
      await pumpScreen(
          tester, const WordGroupsState(status: GroupingInProgress()));
      expect(find.text('Grouping your words…'), findsOneWidget);
      expect(find.byType(GroupPager), findsNothing);
      expect(find.text(groupLine), findsNothing);
      await tickMnemonic(tester);
      expect(startEnabled(tester), isFalse);
    });

    testWidgets(
        'AC-04: failed shows the message and Try again, Start stays off',
        (tester) async {
      await pumpScreen(tester, const WordGroupsState(status: GroupingFailed()));
      expect(find.text('Could not group your words'), findsOneWidget);
      expect(find.byType(GroupPager), findsNothing);
      await tickMnemonic(tester);
      expect(startEnabled(tester), isFalse);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try again'));
      await tester.pumpAndSettle();
      expect(groups.ensured, 2);
    });

    testWidgets('AC-05: waiting words are counted beside the pager',
        (tester) async {
      await pumpScreen(
          tester,
          WordGroupsState(
            status: const GroupingWaiting(4),
            groups: [food, travel],
            selectedGroupId: 'g1',
          ));
      expect(
          find.text(
              '4 more words are waiting for a group (at least 7 are needed)'),
          findsOneWidget);
      expect(find.byType(GroupPager), findsOneWidget);
      await tickMnemonic(tester);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('AC-05: only waiting words and no group leave Start off',
        (tester) async {
      await pumpScreen(
          tester, const WordGroupsState(status: GroupingWaiting(5)));
      expect(
          find.text(
              '5 more words are waiting for a group (at least 7 are needed)'),
          findsOneWidget);
      await tickMnemonic(tester);
      expect(startEnabled(tester), isFalse);
    });

    testWidgets('AC-19: the daily limit is said under the selected group',
        (tester) async {
      await pumpScreen(tester, several(selected: 'g2'), refusals: {
        'g2': const StoryStartRefusal(StoryRefusal.dayLimit),
      });
      expect(find.text(dayLimit), findsOneWidget);
    });

    testWidgets('AC-19: a limit refusal for another group is not shown',
        (tester) async {
      await pumpScreen(tester, several(selected: 'g1'), refusals: {
        'g2': const StoryStartRefusal(StoryRefusal.dayLimit),
      });
      expect(find.text(dayLimit), findsNothing);
    });

    testWidgets('AC-04: Start is unavailable while no group is selected',
        (tester) async {
      await pumpScreen(tester, const WordGroupsState());
      await tickMnemonic(tester);
      expect(startEnabled(tester), isFalse);
      groups.state = WordGroupsState(groups: [all], selectedGroupId: 'g0');
      await tester.pumpAndSettle();
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('fits a phone with the pager and the exercise cards',
        (tester) async {
      await pumpScreen(tester, several(), size: const Size(400, 800));
      expect(tester.takeException(), isNull);
      expect(find.byType(GroupPager), findsOneWidget);
    });
  });

  group('words screen', () {
    testWidgets('AC-03: opening it groups quietly, with no message',
        (tester) async {
      await pumpScreen(tester, several(), home: const WordsTableScreen());
      expect(groups.ensured, 1);
      expect(find.text('Grouping your words…'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
