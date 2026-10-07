import 'dart:math';

import 'package:isar_community/isar.dart';

import 'session_source.dart';
import 'word_group.dart';
import 'word_pair.dart';

part 'session.g.dart';

/// A set of words with an identity and timestamps — what the app calls
/// "the words I am collecting now" versus everything already in history.
/// Persisted by `SessionStore` (Isar collection `sessions`).
@collection
class Session {
  Id id = Isar.autoIncrement;

  /// Device-generated, stable for the lifetime of the session. Task-05 hangs
  /// the shared link on it.
  @Index(unique: true, replace: true)
  late String sessionId;

  /// Last change to the *content* (words). Task-05 will publish this.
  late DateTime updatedAt;

  /// Last time THIS device touched the session: any content change, plus the
  /// moment it is restored from the snackbar. Drives the 5-minute launch rule.
  late DateTime lastLocalModifiedAt;

  /// True once a shared link was created for this session (task-05).
  bool isShared = false;

  List<WordPair> words = [];

  /// Photos taken in this session, in the order they were taken. A row
  /// recognised from one points at it through `WordPair.sourceId`; a session
  /// from before good-looking-web has none (AC-26).
  List<SessionSource> sources = [];

  /// The shared page this session was last published to, and the token that
  /// lets a republish overwrite it (ADR-0008). Null until the first publish.
  String? publishedId;
  String? editToken;

  /// The word groups of the learn page (mnemonic-story, ADR-0003). They live
  /// and die with the session, so a History session keeps its own (AC-11).
  List<WordGroup> groups = [];

  /// The group the learn page is showing; null until grouping has run.
  String? selectedGroupId;

  /// What the words looked like when grouping last ran, to tell whether it
  /// must run again (AC-03).
  String? groupedWordsKey;

  Session();

  static Session create() {
    final now = DateTime.now();
    return Session()
      ..sessionId =
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 32).toRadixString(36)}'
      ..updatedAt = now
      ..lastLocalModifiedAt = now;
  }

  @ignore
  bool get isEmpty => words.every((w) => w.isEmpty);

  factory Session.fromJson(Map<String, dynamic> json) => Session()
    ..sessionId = json['sessionId'] as String? ?? ''
    ..updatedAt = DateTime.parse(json['updatedAt'] as String? ?? '1970-01-01')
    ..lastLocalModifiedAt =
        DateTime.parse(json['lastLocalModifiedAt'] as String? ?? '1970-01-01')
    ..isShared = json['isShared'] as bool? ?? false
    ..words = (json['words'] as List<dynamic>?)
            ?.map((w) => WordPair.fromJson(w as Map<String, dynamic>))
            .toList() ??
        <WordPair>[]
    ..sources = (json['sources'] as List<dynamic>?)
            ?.map((s) => SessionSource.fromJson(s as Map<String, dynamic>))
            .toList() ??
        <SessionSource>[]
    ..publishedId = json['publishedId'] as String?
    ..editToken = json['editToken'] as String?
    ..groups = (json['groups'] as List<dynamic>?)
            ?.map((g) => WordGroup.fromJson(g as Map<String, dynamic>))
            .toList() ??
        <WordGroup>[]
    ..selectedGroupId = json['selectedGroupId'] as String?
    ..groupedWordsKey = json['groupedWordsKey'] as String?;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'updatedAt': updatedAt.toIso8601String(),
        'lastLocalModifiedAt': lastLocalModifiedAt.toIso8601String(),
        'isShared': isShared,
        'words': words.map((w) => w.toJson()).toList(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'publishedId': publishedId,
        'editToken': editToken,
        'groups': groups.map((g) => g.toJson()).toList(),
        'selectedGroupId': selectedGroupId,
        'groupedWordsKey': groupedWordsKey,
      };
}
