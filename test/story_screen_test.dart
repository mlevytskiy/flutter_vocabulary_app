import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_picture_store.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';
import 'package:flutter_vocabulary_app/features/mnemonic_story/story_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';
import 'fake_story_groups.dart';

/// mnemonic-story T17 (AC-06 – AC-09, AC-16, AC-17, AC-19): the story screen
/// shows a saved story, the running step, each failure with its button, the
/// "Words changed" mark and "Make a new story".

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

/// The tracker as the screen sees it: it records what the screen asks and
/// holds the follow count; nothing reaches the Worker.
class _Tracker extends StoryRunTracker {
  _Tracker([this.initial = const StoryTrackerState()]);
  final StoryTrackerState initial;
  int follows = 0;
  int releases = 0;
  final List<({String sessionId, String groupId, bool replacing})> starts = [];
  final List<String> prompts = [];
  final List<String> draws = [];
  StoryActionResult drawResult = const StoryStarted(attempt: 2);

  @override
  StoryTrackerState build() => initial;

  void refuse(String groupId, StoryStartRefusal r) =>
      state = StoryTrackerState(refusals: {groupId: r});

  @override
  StoryFollow follow() {
    follows++;
    return StoryFollow.forTest(() => releases++);
  }

  @override
  Future<String?> startFor(String sessionId, WordGroup group,
      {bool replacing = false}) async {
    starts.add((sessionId: sessionId, groupId: group.id, replacing: replacing));
    return 'new-run';
  }

  @override
  Future<StoryActionResult> redoPrompt(String runId) async {
    prompts.add(runId);
    return const StoryStarted();
  }

  @override
  Future<StoryActionResult> drawAgain(String runId) async {
    draws.add(runId);
    return drawResult;
  }
}

class _Pictures extends StoryPictureStore {
  final List<String> read_ = [];

  @override
  Future<Uint8List?> read(String runId, int attempt) async {
    read_.add('$runId-$attempt');
    return _png;
  }
}

/// A 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

StoryStep step(String role, String outcome,
        {String? text,
        int attempt = 1,
        String? path,
        List<String> missed = const []}) =>
    StoryStep()
      ..role = role
      ..attempt = attempt
      ..outcome = outcome
      ..text = text
      ..picturePath = path
      ..missedWords = [...missed];

StoryRun makeRun(String id, String outcome, List<StoryStep> steps,
        {int minute = 0}) =>
    StoryRun()
      ..runId = id
      ..sessionId = 's1'
      ..groupId = 'g1'
      ..groupName = 'Food'
      ..words = ['apple', 'bread']
      ..startedAt = DateTime(2026, 10, 7, 12, minute)
      ..outcome = outcome
      ..steps = steps;

/// A finished run: story, picture prompt and one picture.
StoryRun doneRun(String id, {int minute = 0, String story = 'An old tale.'}) =>
    makeRun(
        id,
        'done',
        [
          step('story', 'done', text: story),
          step('prompt', 'done', text: 'a picture prompt'),
          step('picture', 'done', path: '/p/$id-1.jpg'),
        ],
        minute: minute);

void main() {
  late Session session;
  late WordGroup theGroup;
  late _Tracker tracker;
  late _Pictures pictures;

  Future<void> pumpScreen(
    WidgetTester tester,
    List<StoryRun> runs, {
    String? storyRunId,
    List<String> storyWords = const ['apple', 'bread'],
    Map<String, StoryStartRefusal> refusals = const {},
    List<String> sessionWords = const ['apple', 'bread'],
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    session = Session.create()
      ..sessionId = 's1'
      ..words = [
        for (var i = 0; i < sessionWords.length; i++)
          WordPair(word: sessionWords[i], translation: 't', rowId: 'r$i'),
      ];
    theGroup = WordGroup()
      ..id = 'g1'
      ..name = 'Food'
      ..rowIds = ['r0', 'r1']
      ..storyRunId = storyRunId
      ..storyWords = [...storyWords];
    session.groups = [theGroup];
    tracker = _Tracker(StoryTrackerState(refusals: refusals));
    pictures = _Pictures();
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      wordGroupsNotifierProvider(null).overrideWith(() => FakeGroups(
          WordGroupsState(groups: [theGroup], selectedGroupId: 'g1'))),
      storyRunTrackerProvider.overrideWith(() => tracker),
      storyPictureStoreProvider.overrideWithValue(pictures),
      groupStoryRunsProvider('g1').overrideWith((ref) => Stream.value(runs)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StoryScreen(groupId: 'g1')),
    ));
    // A running label spins forever, so settle by hand.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  const limit = "Today's story limit is reached. Try again tomorrow.";
  final tryAgain = find.widgetWithText(ElevatedButton, 'Try again');
  final drawAgain = find.widgetWithText(ElevatedButton, 'Draw again');
  final makeNew = find.widgetWithText(ElevatedButton, 'Make a new story');

  group('a saved story', () {
    testWidgets('AC-07: shows the picture over the story and calls nothing',
        (tester) async {
      await pumpScreen(tester, [doneRun('r1')], storyRunId: 'r1');
      expect(find.text('An old tale.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(pictures.read_, ['r1-1']);
      expect(tracker.starts, isEmpty);
      expect(tracker.prompts, isEmpty);
      expect(tracker.draws, isEmpty);
      expect(find.text('Words changed'), findsNothing);
      expect(find.text('Writing the story…'), findsNothing);
      // the picture sits above the story text
      expect(tester.getTopLeft(find.byType(Image)).dy,
          lessThan(tester.getTopLeft(find.text('An old tale.')).dy));
    });

    testWidgets('AC-06: the picture zooms at least 4x', (tester) async {
      await pumpScreen(tester, [doneRun('r1')], storyRunId: 'r1');
      final viewer = tester.widget<InteractiveViewer>(
          find.descendant(
              of: find.byType(StoryScreen),
              matching: find.byType(InteractiveViewer)));
      expect(viewer.maxScale, greaterThanOrEqualTo(4));
    });

    testWidgets('AC-17: an edited word shows Words changed and Make a new story',
        (tester) async {
      await pumpScreen(tester, [doneRun('r1')],
          storyRunId: 'r1', sessionWords: const ['apple', 'bred']);
      expect(find.text('Words changed'), findsOneWidget);
      expect(find.text('An old tale.'), findsOneWidget);
      expect(makeNew, findsOneWidget);
      expect(tracker.starts, isEmpty); // nothing is made on its own
    });
  });

  group('following', () {
    testWidgets('holds one tracker follow while open and lets go when closed',
        (tester) async {
      await pumpScreen(tester, [doneRun('r1')], storyRunId: 'r1');
      expect(tracker.follows, 1);
      expect(tracker.releases, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tracker.releases, 1);
    });
  });

  group('running labels', () {
    testWidgets('AC-06: Writing the story…', (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'running', [step('story', 'running')])
      ]);
      expect(find.text('Writing the story…'), findsOneWidget);
    });

    testWidgets('AC-06: no step yet is still Writing the story…',
        (tester) async {
      await pumpScreen(tester, [makeRun('r1', 'running', [])]);
      expect(find.text('Writing the story…'), findsOneWidget);
    });

    testWidgets('AC-06: Writing the picture prompt…', (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'running',
            [step('story', 'done', text: 'S'), step('prompt', 'running')])
      ]);
      expect(find.text('Writing the picture prompt…'), findsOneWidget);
    });

    testWidgets('AC-06: Drawing the picture…', (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'running', [
          step('story', 'done', text: 'The story text.'),
          step('prompt', 'done', text: 'P'),
          step('picture', 'running'),
        ])
      ]);
      expect(find.text('Drawing the picture…'), findsOneWidget);
    });

    testWidgets('AC-06: a run that ends with a picture shows it in place of the label',
        (tester) async {
      await pumpScreen(tester, [doneRun('r1')]); // group not updated yet
      expect(find.text('An old tale.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Drawing the picture…'), findsNothing);
    });

    testWidgets('AC-06: opening with no run asks the tracker to start one',
        (tester) async {
      await pumpScreen(tester, const []);
      expect(tracker.starts.single.groupId, 'g1');
      expect(tracker.starts.single.sessionId, 's1');
      expect(tracker.starts.single.replacing, isFalse);
    });
  });

  group('failures', () {
    testWidgets('AC-08: missed words are listed; Try again starts a new run',
        (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'failed', [
          step('story', 'failed', text: 'A story.', missed: ['apple', 'bread'])
        ])
      ]);
      expect(find.text('The story missed these words: apple, bread'),
          findsOneWidget);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(tracker.starts.single.replacing, isTrue);
      expect(tracker.starts.single.groupId, 'g1');
    });

    testWidgets('AC-08b: Could not write the story; Try again starts a new run',
        (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'failed', [step('story', 'failed')])
      ]);
      expect(find.text('Could not write the story'), findsOneWidget);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(tracker.starts.single.replacing, isTrue);
      expect(tracker.prompts, isEmpty);
    });

    testWidgets('AC-08b: Could not write the picture prompt; Try again redoes only that step',
        (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'failed',
            [step('story', 'done', text: 'S'), step('prompt', 'failed')])
      ]);
      expect(find.text('Could not write the picture prompt'), findsOneWidget);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(tracker.prompts, ['r1']);
      expect(tracker.starts, isEmpty);
    });

    testWidgets('AC-09: the story with The picture could not be drawn; Draw again redraws',
        (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'failed', [
          step('story', 'done', text: 'The story text.'),
          step('prompt', 'done', text: 'P'),
          step('picture', 'failed'),
        ])
      ]);
      expect(find.text('The story text.'), findsOneWidget);
      expect(find.text('The picture could not be drawn'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.tap(drawAgain);
      await tester.pump();
      expect(tracker.draws, ['r1']);
      expect(tracker.starts, isEmpty);
    });

    testWidgets('AC-19: a refused Draw again shows the limit text',
        (tester) async {
      await pumpScreen(tester, [
        makeRun('r1', 'failed', [
          step('story', 'done', text: 'The story text.'),
          step('prompt', 'done', text: 'P'),
          step('picture', 'failed'),
        ])
      ]);
      tracker.drawResult = const StoryRefused(StoryRefusal.dayLimit);
      await tester.tap(drawAgain);
      tracker.refuse('g1', const StoryStartRefusal(StoryRefusal.dayLimit));
      await tester.pumpAndSettle();
      expect(find.text(limit), findsOneWidget);
      expect(find.text('The story text.'), findsOneWidget);
    });

    testWidgets('AC-19: a first story the limit refused says so',
        (tester) async {
      await pumpScreen(
          tester,
          [makeRun('r1', 'failed', const [])],
          refusals: const {
            'g1': StoryStartRefusal(StoryRefusal.dayLimit)
          });
      expect(find.text(limit), findsOneWidget);
    });

    testWidgets('AC-13: a withdrawn AI is named; Try again starts a new run',
        (tester) async {
      await pumpScreen(
          tester,
          [makeRun('r1', 'failed', const [])],
          refusals: const {
            'g1': StoryStartRefusal(StoryRefusal.notOffered, aiName: 'Zed')
          });
      expect(find.text('Zed is no longer available'), findsOneWidget);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(tracker.starts.single.replacing, isTrue);
    });
  });

  group('Make a new story', () {
    testWidgets('AC-16: Cancel leaves everything as it was', (tester) async {
      await pumpScreen(tester, [doneRun('r1')], storyRunId: 'r1');
      await tester.tap(makeNew);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tracker.starts, isEmpty);
      expect(find.text('An old tale.'), findsOneWidget);
    });

    testWidgets('AC-16: Confirm starts a replacing run', (tester) async {
      await pumpScreen(tester, [doneRun('r1')], storyRunId: 'r1');
      await tester.tap(makeNew);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Make a new story')));
      await tester.pumpAndSettle();
      expect(tracker.starts.single.replacing, isTrue);
      expect(tracker.starts.single.groupId, 'g1');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('AC-16: the old story stays while the new run goes',
        (tester) async {
      await pumpScreen(
          tester,
          [
            makeRun('r2', 'running', [step('story', 'running')], minute: 5),
            doneRun('r1'),
          ],
          storyRunId: 'r1');
      expect(find.text('An old tale.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Writing the story…'), findsOneWidget);
      expect(makeNew, findsNothing); // one run at a time
    });

    testWidgets('AC-16: a failed new story keeps the old one and offers Try again',
        (tester) async {
      await pumpScreen(
          tester,
          [
            makeRun('r2', 'failed', [step('story', 'failed')], minute: 5),
            doneRun('r1'),
          ],
          storyRunId: 'r1');
      expect(find.text('The new story could not be made'), findsOneWidget);
      expect(find.text('An old tale.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(tracker.starts.single.replacing, isTrue);
    });

    testWidgets('AC-19: at the limit the old story stays with the limit text',
        (tester) async {
      await pumpScreen(
          tester,
          [
            makeRun('r2', 'failed', const [], minute: 5),
            doneRun('r1'),
          ],
          storyRunId: 'r1',
          refusals: const {'g1': StoryStartRefusal(StoryRefusal.dayLimit)});
      expect(find.text(limit), findsOneWidget);
      expect(find.text('An old tale.'), findsOneWidget);
      expect(find.text('The new story could not be made'), findsNothing);
    });
  });

  test('StoryRoute sits under learn at story and carries the group', () {
    expect(const StoryRoute(groupId: 'g1').location,
        '/table/learn/story?group-id=g1');
    expect(const StoryRoute(sessionId: 's9', groupId: 'g1').location,
        '/table/learn/story?session-id=s9&group-id=g1');
  });
}
