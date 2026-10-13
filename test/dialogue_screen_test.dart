import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';
import 'package:flutter_vocabulary_app/features/dialogue/dialogue_screen.dart';
import 'package:flutter_vocabulary_app/features/mnemonic_story/story_screen.dart';
import 'package:flutter_vocabulary_app/features/mnemonic_story/widgets/story_picture.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'fake_story_groups.dart';

/// get-words-from-subtitles-improvment T22: the dialogue screen (SCR-07) shows
/// the dialogue and its scene picture: drawn, drawing, or why not (AC-13,
/// AC-14, AC-18, AC-19).

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

class SceneTracker extends FakeTracker {
  SceneTracker(super.initial);
  final calls = <String>[];

  @override
  Future<String?> startScene(String sessionId, WordGroup group) async {
    calls.add('start:${group.id}');
    return null;
  }

  @override
  Future<StoryActionResult> redoPrompt(String runId) async {
    calls.add('redoPrompt:$runId');
    return const StoryStarted();
  }

  @override
  Future<StoryActionResult> drawAgain(String runId) async {
    calls.add('drawAgain:$runId');
    return const StoryStarted();
  }
}

StoryStep step(String role, {String outcome = 'done', int attempt = 1}) => StoryStep()
  ..role = role
  ..attempt = attempt
  ..modelId = 'm'
  ..modelName = 'm'
  ..outcome = outcome
  ..picturePath = role == 'picture' && outcome == 'done' ? '/p.jpg' : null;

StoryRun sceneRun(List<StoryStep> steps, {String outcome = 'running'}) => StoryRun()
  ..runId = 'run-1'
  ..sessionId = 's'
  ..groupId = 'dialogue-d1'
  ..groupName = 'Where is the attic?'
  ..startedAt = DateTime(2026, 10, 13)
  ..kind = StoryRunKind.scene
  ..sceneText = '- Where is the attic?\n- Upstairs.'
  ..steps = steps
  ..outcome = outcome;

void main() {
  final group = WordGroup()
    ..id = 'dialogue-d1'
    ..name = 'Where is the attic?'
    ..rowIds = ['r1']
    ..dialogueId = 'd1';

  Session sessionWith({String? pictureRunId}) => Session.create()
    ..words = [WordPair(word: 'attic', translation: 'горище', rowId: 'r1')]
    ..dialogues = [
      FilmDialogue()
        ..id = 'd1'
        ..lines = ['- Where is the attic?', '- Upstairs.']
        ..wordRowIds = ['r1']
        ..scenePictureRunId = pictureRunId,
    ]
    ..groups = [group];

  late SceneTracker tracker;

  Future<void> pumpScreen(WidgetTester tester, Session session, List<StoryRun> runs,
      {Map<String, StoryStartRefusal> refusals = const {}}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tracker = SceneTracker(StoryTrackerState(refusals: refusals));
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      wordGroupsNotifierProvider(null).overrideWith(
          () => FakeGroups(WordGroupsState(groups: [group], selectedGroupId: group.id))),
      storyRunTrackerProvider.overrideWith(() => tracker),
      groupStoryRunsProvider(group.id).overrideWith((ref) => Stream.value(runs)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(wordInputNotifierProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DialogueScreen(groupId: 'dialogue-d1')),
    ));
    await tester.pump();
    await tester.pump();
  }

  bool atticIsBold(WidgetTester tester) {
    var bold = false;
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'attic' && span.style?.fontWeight == FontWeight.bold) {
          bold = true;
        }
        return true;
      });
    }
    return bold;
  }

  testWidgets('a drawn picture is shown from the phone, nothing started (AC-14)', (tester) async {
    await pumpScreen(tester, sessionWith(pictureRunId: 'run-1'),
        [sceneRun([step('prompt'), step('picture')], outcome: 'done')]);
    expect(find.byType(StoryPicture), findsOneWidget);
    expect(find.text('- Where is the attic?', findRichText: true), findsOneWidget);
    expect(atticIsBold(tester), isTrue);
    expect(tracker.calls, isEmpty);
  });

  testWidgets('without a picture Start draws one, once, and shows the step (AC-13)', (tester) async {
    await pumpScreen(tester, sessionWith(), []);
    expect(tracker.calls, ['start:dialogue-d1']);
    expect(find.text('Writing the picture prompt…'), findsOneWidget);
    expect(atticIsBold(tester), isTrue);
    await tester.pump();
    expect(tracker.calls, hasLength(1));
  });

  testWidgets('while the picture is drawn it says so', (tester) async {
    await pumpScreen(tester, sessionWith(), [sceneRun([step('prompt'), step('picture', outcome: 'running')])]);
    expect(find.text('Drawing the picture…'), findsOneWidget);
    expect(tracker.calls, isEmpty);
  });

  testWidgets('a failed prompt: the message and Try again (AC-18)', (tester) async {
    await pumpScreen(tester, sessionWith(), [sceneRun([step('prompt', outcome: 'failed')], outcome: 'failed')]);
    expect(find.text('Could not write the picture prompt'), findsOneWidget);
    expect(find.text('- Upstairs.', findRichText: true), findsOneWidget, reason: 'the dialogue is still shown');
    await tester.tap(find.text('Try again'));
    expect(tracker.calls, ['redoPrompt:run-1']);
  });

  testWidgets('a failed picture: the message and Draw again (AC-18)', (tester) async {
    await pumpScreen(tester, sessionWith(),
        [sceneRun([step('prompt'), step('picture', outcome: 'failed')], outcome: 'failed')]);
    expect(find.text('The picture could not be drawn'), findsOneWidget);
    await tester.tap(find.text('Draw again'));
    expect(tracker.calls, ['drawAgain:run-1']);
  });

  testWidgets('the day limit: the message and nothing to press (AC-19)', (tester) async {
    await pumpScreen(tester, sessionWith(), [sceneRun([], outcome: 'failed')],
        refusals: {'dialogue-d1': const StoryStartRefusal(StoryRefusal.dayLimit)});
    expect(find.text("Today's story limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(tracker.calls, isEmpty);
  });
}
