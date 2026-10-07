import 'package:isar_community/isar.dart';

part 'word_group.g.dart';

/// One topical group of a session's words on the learn page (mnemonic-story,
/// ADR-0003). Embedded inside `Session`: it lives exactly as long as the
/// session does.
@embedded
class WordGroup {
  String id = '';
  String name = '';

  /// The `WordPair.rowId`s in the group, so it follows its words through edits
  /// and deletions (AC-17).
  List<String> rowIds = [];

  /// The `StoryRun.runId` of the run that made this group's mnemonic story;
  /// null while it has none. Replaced only when a newer run finishes with a
  /// picture (AC-16).
  String? storyRunId;

  /// The English words as they were when the story was made — what tells
  /// "Words changed" (AC-17).
  List<String> storyWords = [];

  WordGroup();

  WordGroup copy() => WordGroup()
    ..id = id
    ..name = name
    ..rowIds = [...rowIds]
    ..storyRunId = storyRunId
    ..storyWords = [...storyWords];

  factory WordGroup.fromJson(Map<String, dynamic> json) => WordGroup()
    ..id = json['id'] as String? ?? ''
    ..name = json['name'] as String? ?? ''
    ..rowIds = [...(json['rowIds'] as List<dynamic>? ?? const []).cast<String>()]
    ..storyRunId = json['storyRunId'] as String?
    ..storyWords =
        [...(json['storyWords'] as List<dynamic>? ?? const []).cast<String>()];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rowIds': rowIds,
        'storyRunId': storyRunId,
        'storyWords': storyWords,
      };
}
