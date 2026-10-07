import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/models/story_run.dart';
import '../../core/models/word_group.dart';
import '../../core/providers.dart';
import '../../core/services/story_api_service.dart';
import '../../core/story/story_run_tracker.dart';
import '../../core/story/word_grouping.dart';
import '../../core/story/word_groups_notifier.dart';
import '../learn/learn_screen.dart' show storyDayLimitMessage;
import '../word_input/word_input_notifier.dart';
import 'widgets/new_story_dialog.dart';

/// Every story run of one group, newest first, re-emitted after each write
/// (the tracker saves the run as it moves on).
final groupStoryRunsProvider = StreamProvider.autoDispose
    .family<List<StoryRun>, String>((ref, groupId) async* {
  final store = await ref.watch(storyRunStoreProvider.future);
  await for (final runs in store.watchNewestFirst()) {
    yield [
      for (final r in runs)
        if (r.groupId == groupId) r
    ];
  }
});

/// The mnemonic story of one group (mnemonic-story, SCR-04): the step that is
/// running, then the picture over the story text, with the failures and their
/// buttons, "Words changed" and "Make a new story" (AC-06 – AC-09, AC-16,
/// AC-17, AC-19). [sessionId] is as on the learn page: none is the current
/// session.
class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  /// Held while the screen is open, so the tracker keeps collecting the run.
  StoryFollow? _follow;
  bool _startAsked = false;

  @override
  void initState() {
    super.initState();
    _follow = ref.read(storyRunTrackerProvider.notifier).follow();
  }

  @override
  void dispose() {
    _follow?.release();
    super.dispose();
  }

  StoryRunTracker get _tracker => ref.read(storyRunTrackerProvider.notifier);

  Session? get _session => widget.sessionId == null
      ? ref.watch(wordInputNotifierProvider).valueOrNull
      : ref.watch(sessionByIdProvider(widget.sessionId!)).valueOrNull;

  /// A new run for [group], replacing what it shows only once it has a picture
  /// (AC-16); also "Try again" after a story failed.
  void _startNew(Session session, WordGroup group) =>
      _tracker.startFor(session.sessionId, group, replacing: true);

  Future<void> _makeNew(Session session, WordGroup group) async {
    if (await confirmNewStory(context)) _startNew(session, group);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final group = ref
        .watch(wordGroupsNotifierProvider(widget.sessionId))
        .groups
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    final runs = ref.watch(groupStoryRunsProvider(widget.groupId));
    final refusal = ref.watch(
        storyRunTrackerProvider.select((s) => s.refusals[widget.groupId]));

    Widget body;
    if (session == null || group == null || runs.valueOrNull == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final list = runs.value!;
      if (list.isEmpty &&
          group.storyRunId == null &&
          refusal == null &&
          !_startAsked) {
        // Start was pressed before the run existed: ask once; a run already
        // made or going is never doubled by the tracker.
        _startAsked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tracker.startFor(session.sessionId, group);
        });
      }
      body = _body(session, group, list, refusal);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Mnemonic story'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: body,
    );
  }

  // --- what to show -------------------------------------------------------

  Widget _body(Session session, WordGroup group, List<StoryRun> runs,
      StoryStartRefusal? refusal) {
    final latest = runs.firstOrNull;
    // The story on show: the group's own, else a run that just finished with
    // a picture before the group has caught up (AC-07, AC-16).
    final saved = runs.where((r) => r.runId == group.storyRunId).firstOrNull;
    final shown =
        saved ?? (latest != null && latest.outcome == 'done' ? latest : null);
    final other =
        latest != null && latest.runId != shown?.runId ? latest : null;

    if (shown == null) return _withoutStory(session, group, latest, refusal);

    final notes = <Widget>[];
    var canMakeNew = true;
    if (other != null && other.outcome == 'running') {
      notes.add(_Label(_stepLabel(other)));
      canMakeNew = false;
    } else if (other != null && other.outcome == 'failed') {
      if (refusal?.reason == StoryRefusal.dayLimit) {
        notes.add(const _Message(storyDayLimitMessage));
      } else {
        notes.add(const _Message('The new story could not be made'));
        notes.add(_Action('Try again', () => _startNew(session, group)));
      }
    } else if (refusal?.reason == StoryRefusal.dayLimit) {
      notes.add(const _Message(storyDayLimitMessage));
    }
    if (isOutdated(session, group)) notes.add(const _Message('Words changed'));
    if (canMakeNew) {
      notes.add(_Action('Make a new story', () => _makeNew(session, group)));
    }
    return _StoryView(run: shown, notes: notes);
  }

  /// A group with no story yet: the running step, or why the run stopped.
  Widget _withoutStory(Session session, WordGroup group, StoryRun? run,
      StoryStartRefusal? refusal) {
    if (run == null) {
      if (refusal?.reason == StoryRefusal.dayLimit) {
        return const _Plain([_Message(storyDayLimitMessage)]);
      }
      return const _Plain([_Label('Writing the story…')]);
    }
    if (run.outcome != 'failed') {
      return _StoryView(
          run: run, notes: [_Label(_stepLabel(run))], pictureWanted: false);
    }

    final story = _last(run, 'story');
    final prompt = _last(run, 'prompt');
    final picture = _last(run, 'picture');
    final startNew = _Action('Try again', () => _startNew(session, group));
    if (story == null && run.steps.isEmpty) {
      // The run never started: the Worker refused, or could not be reached.
      return _Plain([
        _Message(_refusalText(refusal)),
        if (refusal?.reason != StoryRefusal.dayLimit) startNew
      ]);
    }
    if (story == null || story.outcome == 'failed') {
      final missed = story?.missedWords ?? const <String>[];
      return _Plain([
        _Message(missed.isEmpty
            ? 'Could not write the story'
            : 'The story missed these words: ${missed.join(', ')}'),
        startNew,
      ]);
    }
    if (prompt == null || prompt.outcome == 'failed') {
      return _Plain([
        const _Message('Could not write the picture prompt'),
        _Action('Try again', () => _tracker.redoPrompt(run.runId)),
      ]);
    }
    return _StoryView(run: run, pictureWanted: false, notes: [
      if (refusal?.reason == StoryRefusal.dayLimit)
        const _Message(storyDayLimitMessage)
      else ...[
        _Message(picture?.outcome == 'failed'
            ? 'The picture could not be drawn'
            : 'Could not finish the story'),
        _Action('Draw again', () => _tracker.drawAgain(run.runId)),
      ],
    ]);
  }

  String _refusalText(StoryStartRefusal? refusal) => switch (refusal?.reason) {
        StoryRefusal.dayLimit => storyDayLimitMessage,
        StoryRefusal.notOffered =>
          '${refusal?.aiName ?? 'That AI'} is no longer available',
        _ =>
          'The story could not be started. Check your connection and try again.',
      };

  static StoryStep? _last(StoryRun run, String role) =>
      run.steps.where((s) => s.role == role).lastOrNull;

  /// The step a running run is on (AC-06).
  static String _stepLabel(StoryRun run) {
    final story = _last(run, 'story');
    if (story == null || story.outcome != 'done') return 'Writing the story…';
    final prompt = _last(run, 'prompt');
    if (prompt == null || prompt.outcome != 'done') {
      return 'Writing the picture prompt…';
    }
    return 'Drawing the picture…';
  }
}

// --- parts ---------------------------------------------------------------

/// A column of messages and buttons in the middle of the screen.
class _Plain extends StatelessWidget {
  const _Plain(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
}

/// The picture over the story text, with [notes] between the bar and them.
/// The picture zooms and pans in place with two fingers (AC-06).
class _StoryView extends ConsumerWidget {
  const _StoryView(
      {required this.run, required this.notes, this.pictureWanted = true});

  final StoryRun run;
  final List<Widget> notes;

  /// False while the picture is not there (still being drawn, or failed).
  final bool pictureWanted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = _StoryScreenState._last(run, 'story');
    final picture = pictureWanted
        ? run.steps
            .where((s) =>
                s.role == 'picture' &&
                s.outcome == 'done' &&
                s.picturePath != null)
            .lastOrNull
        : null;
    return Column(
      children: [
        if (picture != null)
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.4,
            width: double.infinity,
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: FutureBuilder<Uint8List?>(
                  future: ref
                      .read(storyPictureStoreProvider)
                      .read(run.runId, picture.attempt),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    return bytes == null
                        ? const SizedBox.expand()
                        : Image.memory(bytes,
                            fit: BoxFit.contain, width: double.infinity);
                  },
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (story?.text != null)
                Text(story!.text!,
                    style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Center(child: Column(children: notes)),
            ],
          ),
        ),
      ],
    );
  }
}
