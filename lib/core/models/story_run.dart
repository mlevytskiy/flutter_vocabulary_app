import 'package:isar_community/isar.dart';

part 'story_run.g.dart';

/// One mnemonic story run (mnemonic-story, ADR-0003): a record of what the AIs
/// did for a group's words. Listed across all sessions, newest first, and
/// never removed — not by a newer story, not by a changed group (AC-14,
/// AC-15). The group's story is the run its `WordGroup.storyRunId` names.
@collection
class StoryRun {
  Id id = Isar.autoIncrement;

  /// App-generated; also the Worker's run id, so a repeated start finds the
  /// same run.
  @Index(unique: true, replace: true)
  late String runId;

  late String sessionId;
  late String groupId;

  /// The group's name when the run started: the run outlives the group.
  late String groupName;

  /// The English words the run was made for.
  List<String> words = [];

  @Index()
  late DateTime startedAt;

  /// The offered-list ids chosen for the run, in step order: story writer,
  /// picture prompt writer, picture maker.
  List<String> models = [];

  /// One per attempt: the story, the picture prompt, and every picture try.
  List<StoryStep> steps = [];

  /// `running`, `done` or `failed`.
  String outcome = 'running';

  /// True once the app has copied the Worker's results (picture included) to
  /// the phone.
  bool collected = false;

  StoryRun();
}

/// One attempt at one step of a [StoryRun].
@embedded
class StoryStep {
  /// `story`, `prompt` or `picture`.
  String role = '';

  /// 1 for the story and the prompt; counts up for each picture try.
  int attempt = 1;

  String modelId = '';
  String modelName = '';

  /// `running`, `done` or `failed`.
  String outcome = 'running';

  /// The story, or the picture prompt.
  String? text;

  /// The picture's file under `mnemonic_pictures/`.
  String? picturePath;

  /// Words the story left out (AC-08); empty when it kept them all.
  List<String> missedWords = [];

  /// Null until the step has a price.
  double? priceUsd;

  /// True when the price is an estimate, as after a timeout.
  bool priceEstimated = false;

  /// How long the step took; null until it finished.
  int? ms;
}
