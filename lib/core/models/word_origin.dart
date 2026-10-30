import 'package:isar_community/isar.dart';

part 'word_origin.g.dart';

/// Where a row's word came from (word-context AC-01, ADR-0001). Stored by
/// name: a renamed value would read back as the default, so the names are
/// pinned.
enum SourceType { manuallyEntered, movie, image, set }

/// What a row's `WordPair.context` holds: nothing, a line from the row's own
/// source (subtitles, photo), or an example the AI wrote. Stored by name.
enum ContextKind { none, source, ai }

/// The origin record of one word row (word-context ADR-0001). Embedded inside
/// `WordPair.origin`; a row stored before word-context reads it back with
/// these defaults. The film fields are filled for a [SourceType.movie] row
/// only, and each may stay empty.
@embedded
class WordOrigin {
  @Enumerated(EnumType.name)
  SourceType typeOfSource = SourceType.manuallyEntered;

  /// The film's or the series' name; '' when unknown.
  String movieName = '';

  int? season;
  int? episode;

  /// Where in the film the word is said, as `hh:mm:ss`; '' when unknown.
  String time = '';

  /// The learner changed the translation or the description by hand.
  bool wasTranslationEditByUser = false;
  bool wasDescriptionEditByUser = false;

  WordOrigin();

  WordOrigin copy() => WordOrigin()
    ..typeOfSource = typeOfSource
    ..movieName = movieName
    ..season = season
    ..episode = episode
    ..time = time
    ..wasTranslationEditByUser = wasTranslationEditByUser
    ..wasDescriptionEditByUser = wasDescriptionEditByUser;

  factory WordOrigin.fromJson(Map<String, dynamic> json) => WordOrigin()
    ..typeOfSource = SourceType.values.asNameMap()[json['typeOfSource']] ??
        SourceType.manuallyEntered
    ..movieName = json['movieName'] as String? ?? ''
    ..season = json['season'] as int?
    ..episode = json['episode'] as int?
    ..time = json['time'] as String? ?? ''
    ..wasTranslationEditByUser =
        json['wasTranslationEditByUser'] as bool? ?? false
    ..wasDescriptionEditByUser =
        json['wasDescriptionEditByUser'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'typeOfSource': typeOfSource.name,
        'movieName': movieName,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        'time': time,
        'wasTranslationEditByUser': wasTranslationEditByUser,
        'wasDescriptionEditByUser': wasDescriptionEditByUser,
      };
}
