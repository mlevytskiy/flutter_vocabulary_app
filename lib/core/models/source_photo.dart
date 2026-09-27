import 'package:isar_community/isar.dart';

part 'source_photo.g.dart';

/// A photo the learner took in a session, kept on the phone so it can be
/// published with the rows recognised from it (good-looking-web, sad §5).
/// Embedded inside [Session]: a photo lives exactly as long as its session.
/// The bytes are a file in the app documents dir (`SourcePhotoStore`); this is
/// only the reference.
@embedded
class SourcePhoto {
  /// UUID given when the photo is taken. Rows recognised from it carry it as
  /// `WordPair.sourceId`, and publishing declares the photo under it (ADR-0006).
  String id = '';

  /// The kept file's name inside the store's directory.
  String fileName = '';

  /// Publishing declares the first 10 photos by this time (spec OQ-3).
  DateTime takenAt = DateTime.fromMillisecondsSinceEpoch(0);

  SourcePhoto();

  factory SourcePhoto.fromJson(Map<String, dynamic> json) => SourcePhoto()
    ..id = json['id'] as String? ?? ''
    ..fileName = json['fileName'] as String? ?? ''
    ..takenAt = DateTime.parse(json['takenAt'] as String? ?? '1970-01-01');

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'takenAt': takenAt.toIso8601String(),
      };

  SourcePhoto copy() => SourcePhoto()
    ..id = id
    ..fileName = fileName
    ..takenAt = takenAt;
}
