import 'package:isar_community/isar.dart';

part 'film_dialogue.g.dart';

/// Where a dialogue or its scene picture is on its way to the shared link
/// (ADR-0005). Stored as the ordinal: keep `none` first so records saved
/// before it existed read back as nothing to deliver.
enum PushState { none, pending, delivered }

/// A short exchange from a subtitle file, kept with the words it holds
/// (get-words-from-subtitles-improvment, ADR-0003). Embedded inside `WordCollection`,
/// in pager order: it lives exactly as long as the session does.
@embedded
class FilmDialogue {
  /// UUID made by the app; the Worker keeps it, so the append, the picture
  /// upload and the change feed agree.
  String id = '';

  /// The dialogue's lines, in order, as the AI returned them.
  List<String> lines = [];

  /// The `WordPair.rowId`s linked at Done. Only ever shrinks (AC-11).
  List<String> wordRowIds = [];

  /// The `StoryRun.runId` of the scene run whose picture this dialogue shows;
  /// null until one was drawn (AC-14).
  String? scenePictureRunId;

  /// The import that brought the dialogue, so a repeated append adds nothing
  /// twice; null when the session had no shared link at Done (ADR-0005).
  String? importId;

  /// Every row that import added, sent with the dialogue on append.
  List<String> importRowIds = [];

  /// The dialogue's own delivery to the shared link.
  @enumerated
  PushState pushState = PushState.none;

  /// The scene picture's delivery to the shared link.
  @enumerated
  PushState picturePushState = PushState.none;

  /// A pending dialogue left without words: no page, no group, not published,
  /// until its import is delivered and it is removed (ADR-0005).
  bool hidden = false;

  FilmDialogue();

  FilmDialogue copy() => FilmDialogue()
    ..id = id
    ..lines = [...lines]
    ..wordRowIds = [...wordRowIds]
    ..scenePictureRunId = scenePictureRunId
    ..importId = importId
    ..importRowIds = [...importRowIds]
    ..pushState = pushState
    ..picturePushState = picturePushState
    ..hidden = hidden;

  factory FilmDialogue.fromJson(Map<String, dynamic> json) => FilmDialogue()
    ..id = json['id'] as String? ?? ''
    ..lines = [...(json['lines'] as List<dynamic>? ?? const []).cast<String>()]
    ..wordRowIds =
        [...(json['wordRowIds'] as List<dynamic>? ?? const []).cast<String>()]
    ..scenePictureRunId = json['scenePictureRunId'] as String?
    ..importId = json['importId'] as String?
    ..importRowIds =
        [...(json['importRowIds'] as List<dynamic>? ?? const []).cast<String>()]
    ..pushState =
        PushState.values.asNameMap()[json['pushState']] ?? PushState.none
    ..picturePushState =
        PushState.values.asNameMap()[json['picturePushState']] ??
            PushState.none
    ..hidden = json['hidden'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lines': lines,
        'wordRowIds': wordRowIds,
        'scenePictureRunId': scenePictureRunId,
        'importId': importId,
        'importRowIds': importRowIds,
        'pushState': pushState.name,
        'picturePushState': picturePushState.name,
        'hidden': hidden,
      };
}
