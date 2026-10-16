import 'package:isar_community/isar.dart';

part 'session_source.g.dart';

/// Which kind of source a [SessionSource] is. Stored as the ordinal: keep
/// `photo` first so records saved before `kind` existed read back as photos.
/// New kinds go at the end, never in between: `subtitles` is a film or
/// episode whose subtitles the words were picked from (side-panel-sources,
/// spec AC-22).
enum SourceKind { photo, set, subtitles }

/// Where a session's words came from: a photo the learner took, kept on the
/// phone so it can be published with the rows recognised from it
/// (good-looking-web, sad §5), or a Quizlet set the learner imported
/// (import-from-quizlet, ADR-0005), or a film's subtitles the learner
/// imported (side-panel-sources, spec AC-22).
/// Embedded inside [WordCollection]: a source lives exactly as long as its session.
/// A photo's bytes are a file in the app documents dir (`SourcePhotoStore`);
/// this is only the reference.
/// The stored name stays `SourcePhoto` so sessions saved before keep reading.
@Name('SourcePhoto')
@embedded
class SessionSource {
  /// UUID given when the photo is taken. Rows recognised from it carry it as
  /// `WordPair.sourceId`, and publishing declares the photo under it (ADR-0006).
  String id = '';

  /// The kept file's name inside the store's directory.
  String fileName = '';

  /// Publishing declares the first 10 photos by this time (spec OQ-3).
  DateTime takenAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Photo or set. A record or JSON without it is a photo.
  @enumerated
  SourceKind kind = SourceKind.photo;

  /// A set's title on Quizlet, or the film's or episode's title shown to the
  /// learner (set and subtitles sources only).
  String? name;

  /// A set's plain address, `https://quizlet.com/<id>/<slug>/` (set
  /// sources), or a film's poster address from the subtitle search, when it
  /// was found by name (subtitles sources; owner, 2026-10-15).
  String? url;

  /// The learner's note on this source, edited on the Notes page (owner,
  /// 2026-10-15, notes-editing): a title shown instead of the source's own
  /// name when set, a description, any number of links and of tags. Kept on
  /// the phone only, never published.
  String? title;
  String? description;
  List<String> links = [];
  List<String> tags = [];

  SessionSource();

  factory SessionSource.fromJson(Map<String, dynamic> json) => SessionSource()
    ..id = json['id'] as String? ?? ''
    ..fileName = json['fileName'] as String? ?? ''
    ..takenAt = DateTime.parse(json['takenAt'] as String? ?? '1970-01-01')
    ..kind = SourceKind.values.asNameMap()[json['kind']] ?? SourceKind.photo
    ..name = json['name'] as String?
    ..url = json['url'] as String?
    ..title = json['title'] as String?
    ..description = json['description'] as String?
    ..links = [...?(json['links'] as List<dynamic>?)?.cast<String>()]
    ..tags = [...?(json['tags'] as List<dynamic>?)?.cast<String>()];

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'takenAt': takenAt.toIso8601String(),
        'kind': kind.name,
        if (name != null) 'name': name,
        if (url != null) 'url': url,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (links.isNotEmpty) 'links': links,
        if (tags.isNotEmpty) 'tags': tags,
      };

  SessionSource copy() => SessionSource()
    ..id = id
    ..fileName = fileName
    ..takenAt = takenAt
    ..kind = kind
    ..name = name
    ..url = url
    ..title = title
    ..description = description
    ..links = [...links]
    ..tags = [...tags];
}
