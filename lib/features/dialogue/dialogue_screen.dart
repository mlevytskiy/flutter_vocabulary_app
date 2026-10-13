import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/film_dialogue.dart';
import '../../core/models/session.dart';
import '../../core/models/story_run.dart';
import '../../core/models/word_group.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/story_api_service.dart';
import '../../core/story/story_run_tracker.dart';
import '../../core/story/word_groups_notifier.dart';
import '../learn/learn_screen.dart' show storyDayLimitMessage;
import '../mnemonic_story/story_screen.dart' show groupStoryRunsProvider;
import '../mnemonic_story/widgets/story_parts.dart';
import '../mnemonic_story/widgets/story_picture.dart';
import '../word_input/widgets/dialogue_page.dart' show boldSpans;
import '../word_input/word_input_notifier.dart';

/// "Dialogs from movie" for one dialogue group (get-words-from-subtitles-
/// improvment SCR-07): the scene picture over the dialogue, its words in bold.
/// A picture already drawn is shown from the phone and nothing is paid; else
/// opening the screen draws one, with its progress and failures as on the
/// story screen (AC-13, AC-14, AC-18, AC-19). [sessionId] is as on the learn
/// page: none is the current session.
class DialogueScreen extends ConsumerStatefulWidget {
  const DialogueScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  ConsumerState<DialogueScreen> createState() => _DialogueScreenState();
}

class _DialogueScreenState extends ConsumerState<DialogueScreen> {
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

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final group = ref
        .watch(wordGroupsNotifierProvider(widget.sessionId))
        .groups
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    final dialogue = session?.dialogues
        .where((d) => d.id == group?.dialogueId)
        .firstOrNull;
    final runs = ref.watch(groupStoryRunsProvider(widget.groupId));
    final refusal = ref.watch(
        storyRunTrackerProvider.select((s) => s.refusals[widget.groupId]));

    Widget body;
    if (session == null ||
        group == null ||
        dialogue == null ||
        runs.valueOrNull == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final scenes = [
        for (final r in runs.value!)
          if (r.kind == StoryRunKind.scene) r,
      ];
      if (scenes.isEmpty &&
          dialogue.scenePictureRunId == null &&
          refusal == null &&
          !_startAsked) {
        // Start was pressed: draw once; the tracker never doubles a run.
        _startAsked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tracker.startScene(session.sessionId, group);
        });
      }
      body = _body(session, group, dialogue, scenes, refusal);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Dialogs from movie'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: body,
    );
  }

  Widget _body(Session session, WordGroup group, FilmDialogue dialogue,
      List<StoryRun> scenes, StoryStartRefusal? refusal) {
    final saved =
        scenes.where((r) => r.runId == dialogue.scenePictureRunId).firstOrNull;
    final latest = scenes.firstOrNull;
    // The picture on show: the dialogue's own, else a run that just finished
    // before the dialogue has caught up.
    final shown = saved ?? (latest?.outcome == 'done' ? latest : null);
    final picture = shown == null ? null : _last(shown, 'picture');

    final List<Widget> top;
    if (shown != null && picture != null) {
      top = [StoryPicture(runId: shown.runId, attempt: picture.attempt)];
    } else {
      top = [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: _status(session, group, latest, refusal)),
        ),
      ];
    }
    return Column(
      children: [
        ...top,
        Expanded(child: _Lines(dialogue: dialogue, words: session.words)),
      ],
    );
  }

  /// No picture yet: the running step, or why the run stopped.
  List<Widget> _status(Session session, WordGroup group, StoryRun? run,
      StoryStartRefusal? refusal) {
    if (run == null) {
      if (refusal?.reason == StoryRefusal.dayLimit) {
        return const [StoryMessage(storyDayLimitMessage)];
      }
      return const [StoryLabel('Writing the picture prompt…')];
    }
    final prompt = _last(run, 'prompt');
    final picture = _last(run, 'picture');
    if (run.outcome != 'failed') {
      return [
        StoryLabel(prompt?.outcome == 'done'
            ? 'Drawing the picture…'
            : 'Writing the picture prompt…'),
      ];
    }
    if (run.steps.isEmpty) {
      // The run never started: the Worker refused, or could not be reached.
      return [
        StoryMessage(_refusalText(refusal)),
        if (refusal?.reason != StoryRefusal.dayLimit)
          StoryAction('Try again', () {
            _tracker.startScene(session.sessionId, group);
          }),
      ];
    }
    if (prompt == null || prompt.outcome == 'failed') {
      return [
        const StoryMessage('Could not write the picture prompt'),
        StoryAction('Try again', () => _tracker.redoPrompt(run.runId)),
      ];
    }
    if (refusal?.reason == StoryRefusal.dayLimit) {
      return const [StoryMessage(storyDayLimitMessage)];
    }
    return [
      StoryMessage(picture?.outcome == 'failed'
          ? 'The picture could not be drawn'
          : 'Could not finish the picture'),
      StoryAction('Draw again', () => _tracker.drawAgain(run.runId)),
    ];
  }

  String _refusalText(StoryStartRefusal? refusal) => switch (refusal?.reason) {
        StoryRefusal.dayLimit => storyDayLimitMessage,
        StoryRefusal.notOffered =>
          '${refusal?.aiName ?? 'That AI'} is no longer available',
        _ =>
          'The picture could not be started. Check your connection and try again.',
      };

  static StoryStep? _last(StoryRun run, String role) =>
      run.steps.where((s) => s.role == role).lastOrNull;
}

/// The dialogue's lines with every dialogue word in bold, as on its page.
class _Lines extends StatelessWidget {
  const _Lines({required this.dialogue, required this.words});

  final FilmDialogue dialogue;
  final List<WordPair> words;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final w in words) w.rowId: w};
    final dialogueWords = [
      for (final id in dialogue.wordRowIds)
        if (byId[id] case final w? when !w.isEmpty) w,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final line in dialogue.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(children: boldSpans(line, dialogueWords)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
      ],
    );
  }
}
