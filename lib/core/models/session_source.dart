import 'package:isar_community/isar.dart';

part 'session_source.g.dart';

/// Which kind of source a [SessionSource] is. Stored as the ordinal: keep
/// `photo` first so records saved before `kind` existed read back as photos.
enum SourceKind { photo, set }

/// Where a session's words came from: a photo the learner took, kept on the
/// phone so it can be published with the rows recognised from it
/// (good-looking-web, sad §5), or a Quizlet set the learner imported
/// (import-from-quizlet, ADR-0005).
/// Embedded inside [Session]: a source lives exactly as long as its session.
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

  /// A set's title on Quizlet (set sources only).
  String? name;

  /// A set's plain address, `https://quizlet.com/<id>/<slug>/` (set sources
  /// only).
  String? url;

  SessionSource();

  factory SessionSource.fromJson(Map<String, dynamic> json) => SessionSource()
    ..id = json['id'] as String? ?? ''
    ..fileName = json['fileName'] as String? ?? ''
    ..takenAt = DateTime.parse(json['takenAt'] as String? ?? '1970-01-01')
    ..kind = SourceKind.values.asNameMap()[json['kind']] ?? SourceKind.photo
    ..name = json['name'] as String?
    ..url = json['url'] as String?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'takenAt': takenAt.toIso8601String(),
        'kind': kind.name,
        if (name != null) 'name': name,
        if (url != null) 'url': url,
      };

  SessionSource copy() => SessionSource()
    ..id = id
    ..fileName = fileName
    ..takenAt = takenAt
    ..kind = kind
    ..name = name
    ..url = url;
}
