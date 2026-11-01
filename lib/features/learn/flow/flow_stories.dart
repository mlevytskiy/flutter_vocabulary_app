import 'package:flutter/foundation.dart';

import '../../../core/models/story_run.dart';
import '../../../core/models/word_collection.dart';
import '../../../core/models/word_group.dart';
import '../../../core/models/word_origin.dart';
import '../../../core/models/word_pair.dart';

/// The story side of the Learn flow (learn-welcome AC-09, AC-10; proxy Q9):
/// which saved story a group reuses, the `WordGroup` a new run is started
/// for, and where a run stands. Pure: the flow notifier reads the store and
/// the tracker and hands the runs in.

/// Where one story group's story stands.
enum FlowStoryStatus {
  /// Looking for a saved story or starting a run.
  starting,

  /// A run is going ("Writing your story…").
  writing,

  /// The picture is on the phone.
  ready,

  /// No run could start, or the run failed: it stays only in Story runs.
  failed,
}

/// One story group of the flow (the first 3 groups, AC-06) and its story.
@immutable
class FlowStory {
  const FlowStory({
    required this.index,
    required this.groupId,
    required this.rowIds,
    this.runId,
    this.reused = false,
    this.status = FlowStoryStatus.starting,
    this.picturePath,
    this.progress = 0,
  });

  /// 0-based story group index, as in `StorySlots`.
  final int index;

  /// The id the flow's runs carry as `StoryRun.groupId` ([flowGroupId]).
  final String groupId;

  /// The group's row ids, in card order.
  final List<String> rowIds;

  /// The run that makes (or made) the story; null until one started.
  final String? runId;

  /// True when a finished saved story was reused (no new run).
  final bool reused;
  final FlowStoryStatus status;

  /// The story picture on the phone once [status] is ready.
  final String? picturePath;

  /// How far the run got, 0–1 (story, picture prompt, picture), for the
  /// wait page's progress bar.
  final double progress;

  FlowStory copyWith({
    String? runId,
    bool? reused,
    FlowStoryStatus? status,
    String? picturePath,
    double? progress,
  }) =>
      FlowStory(
        index: index,
        groupId: groupId,
        rowIds: rowIds,
        runId: runId ?? this.runId,
        reused: reused ?? this.reused,
        status: status ?? this.status,
        picturePath: picturePath ?? this.picturePath,
        progress: progress ?? this.progress,
      );
}

/// The `StoryRun.groupId` of a flow group: its row ids, sorted, so the same
/// set of words always gives the same id and a later Learn finds its story.
String flowGroupId(List<WordPair> rows) {
  final ids = [for (final r in rows) r.rowId]..sort();
  return 'learn:${ids.join(',')}';
}

/// The group a new run is started for (the tracker reads its row ids and
/// name; the group is not added to the collection's learn-page groups).
WordGroup flowWordGroup(List<WordPair> rows) {
  final words = [
    for (final r in rows)
      if (r.word.trim().isNotEmpty) r.word.trim(),
  ];
  final shown = words.take(3).join(', ');
  return WordGroup()
    ..id = flowGroupId(rows)
    ..name = words.length > 3 ? 'Learn: $shown…' : 'Learn: $shown'
    ..rowIds = [for (final r in rows) r.rowId];
}

/// The per-word hints a flow story run sends to the story writer (learn-welcome
/// AC-12): the word; its context sentence when it has one; where it came from
/// (a film with its season and episode, a photo, a Quizlet set; nothing for a
/// typed word); and the translation only when the learner edited it.
List<Map<String, String>> storyExtras(List<WordPair> rows) {
  final extras = <Map<String, String>>[];
  for (final r in rows) {
    final word = r.word.trim();
    if (word.isEmpty) continue;
    final o = r.origin;
    final context = r.context.trim();
    final source = switch (o.typeOfSource) {
      SourceType.movie => _filmSource(o),
      SourceType.image => 'a photo',
      SourceType.set => 'a Quizlet set',
      SourceType.manuallyEntered => '',
    };
    final translation = r.translation.trim();
    extras.add({
      'word': word,
      if (context.isNotEmpty) 'context': context,
      if (source.isNotEmpty) 'source': source,
      if (o.wasTranslationEditByUser && translation.isNotEmpty) 'translation': translation,
    });
  }
  return extras;
}

String _filmSource(WordOrigin o) {
  final name = o.movieName.trim();
  if (name.isEmpty) return 'a film';
  final s = o.season, e = o.episode;
  String two(int n) => n.toString().padLeft(2, '0');
  final tag = s != null && e != null ? ' S${two(s)}E${two(e)}' : '';
  return 'film $name$tag';
}

/// The picture of a finished, collected story run; null otherwise.
String? storyPicture(StoryRun run) => storyPictureStep(run)?.picturePath;

/// The picture step of a finished, collected story run; null otherwise.
StoryStep? storyPictureStep(StoryRun run) {
  if (run.kind != StoryRunKind.story ||
      run.outcome != 'done' ||
      !run.collected) {
    return null;
  }
  for (final s in run.steps.reversed) {
    if (s.role == 'picture') return s;
  }
  return null;
}

/// A finished saved story of [collection] whose set of row ids equals
/// [rows]' (proxy Q9): a run of an earlier flow for the same words, or the
/// story of a learn-page group holding exactly these rows. Newest first in
/// [runsNewestFirst]; null when there is none.
StoryRun? reusableStory(
  WordCollection collection,
  List<WordPair> rows,
  List<StoryRun> runsNewestFirst,
) {
  final want = {for (final r in rows) r.rowId};
  final groupIds = {
    flowGroupId(rows),
    for (final g in collection.groups)
      if (g.dialogueId == null && setEquals(g.rowIds.toSet(), want)) g.id,
  };
  for (final run in runsNewestFirst) {
    if (run.collectionId == collection.collectionId &&
        groupIds.contains(run.groupId) &&
        storyPicture(run) != null) {
      return run;
    }
  }
  return null;
}

/// A run of an earlier flow for exactly [rows] that is still going, so a
/// second Learn follows it instead of starting another.
StoryRun? runningStory(
  String collectionId,
  List<WordPair> rows,
  List<StoryRun> runsNewestFirst,
) {
  final id = flowGroupId(rows);
  for (final run in runsNewestFirst) {
    if (run.collectionId == collectionId &&
        run.groupId == id &&
        run.kind == StoryRunKind.story &&
        run.outcome == 'running') {
      return run;
    }
  }
  return null;
}

/// [story] as [run] now stands: writing with its progress, ready with the
/// picture, or failed.
FlowStory followRun(FlowStory story, StoryRun? run) {
  if (run == null) return story;
  final picture = storyPicture(run);
  if (picture != null) {
    return story.copyWith(
        status: FlowStoryStatus.ready, picturePath: picture, progress: 1);
  }
  if (run.outcome == 'failed') {
    return story.copyWith(status: FlowStoryStatus.failed);
  }
  final done = {
    for (final s in run.steps)
      if (s.outcome == 'done') s.role,
  };
  return story.copyWith(
    status: FlowStoryStatus.writing,
    progress: done.length.clamp(0, 3) / 3,
  );
}
