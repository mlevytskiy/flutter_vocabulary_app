import 'dart:math';

import 'package:isar_community/isar.dart';

import 'film_dialogue.dart';
import 'name_kind.dart';
import 'session_source.dart';
import 'word_box.dart';
import 'word_group.dart';
import 'word_pair.dart';
import 'word_result.dart';

part 'word_collection.g.dart';

/// A set of words with an identity and timestamps — what the app calls
/// "the words I am collecting now" versus everything already in history.
/// Persisted by `CollectionStore`. Stored as the Isar collection `Session`
/// and its `sessionId`: the old names are pinned with `@Name` (ADR-0002).
@collection
@Name('Session')
class WordCollection {
  Id id = Isar.autoIncrement;

  /// Device-generated, stable for the lifetime of the session. Task-05 hangs
  /// the shared link on it.
  @Index(unique: true, replace: true)
  @Name('sessionId')
  late String collectionId;

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

  /// The film dialogues kept from subtitle imports, in pager order
  /// (get-words-from-subtitles-improvment, ADR-0003). A session from before
  /// has none.
  List<FilmDialogue> dialogues = [];

  /// The Step 3 word results (learn-kit, S-22), append-only, newest last, at
  /// most [maxResults]. Written only through `CollectionStore.appendResult` — a
  /// result is not a word edit, so it moves neither time — and read through
  /// the `ExamResultSink`. A session from before has none.
  List<WordResult> results = [];

  /// The Leitner boxes of the learning sessions (learn-redesign, ADR-0001),
  /// one per word row. Written only through `CollectionStore.update` (one
  /// transaction at a session's end, ADR-0002); `put` keeps the stored ones,
  /// so a stale words-table copy never erases or rolls them back (AC-15). A
  /// collection from before has none.
  List<WordBox> boxes = [];

  /// Tags for the whole session, edited at the top of the Notes page (owner,
  /// 2026-10-15, notes-editing). A source's own tags live on the source.
  List<String> tags = [];

  /// The learner's description of the collection and its typed tags
  /// (collection-tags, ADR-0001). Legacy [tags] stays untouched.
  String? description;

  /// Where [description] came from (collection-naming, owner 2026-10-18):
  /// `undefined` while it is empty and nobody wrote one, `auto` once the AI
  /// wrote it at [minWordsForAutoDescription] words, `byUser` once the
  /// learner changed it (an emptied one too). Written only by the store.
  @enumerated
  NameKind descriptionKind = NameKind.undefined;
  List<String> originTags = [];
  List<String> topicTags = [];

  // --- filing (collections-screen, ADR-0003, ADR-0005) --------------------
  // Copied from the stored record by `CollectionStore.put()`, never from the
  // caller: only the store's filing transactions write them (data-model.md).

  /// The display name, 1–60 characters, one line (`collection_name.dart`).
  /// Written by `CollectionStore.create()` and rename; null only on a record
  /// from before collections-screen until the backfill names it.
  String? name;

  /// Where [name] came from (collection-naming, owner 2026-10-18): written
  /// only by the store, with the name. A record from before reads as
  /// `undefined` until the store's naming migration sorts it.
  @enumerated
  NameKind nameKind = NameKind.undefined;

  /// The `CollectionFolder.folderId` it sits in; null is the top level.
  @Index()
  String? folderId;

  /// Its place in its level, shared with that level's folders.
  int order = 0;

  /// When the learner deleted it; null when it is not in the bin (ADR-0005).
  @Index()
  DateTime? binnedAt;

  /// The folder it was deleted from, the restore target (AC-24).
  String? binnedFromFolderId;

  /// True once made with New collection, renamed, moved, reordered or given
  /// a word (AC-19). Never set back to false.
  bool keep = false;

  /// The most results a session keeps; the oldest goes first (AC-38).
  static const maxResults = 2000;

  WordCollection();

  static WordCollection create() {
    final now = DateTime.now();
    return WordCollection()
      ..collectionId =
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 32).toRadixString(36)}'
      ..updatedAt = now
      ..lastLocalModifiedAt = now;
  }

  @ignore
  bool get isEmpty => words.every((w) => w.isEmpty);

  factory WordCollection.fromJson(Map<String, dynamic> json) => WordCollection()
    ..collectionId = json['sessionId'] as String? ?? ''
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
    ..groupedWordsKey = json['groupedWordsKey'] as String?
    ..dialogues = (json['dialogues'] as List<dynamic>?)
            ?.map((d) => FilmDialogue.fromJson(d as Map<String, dynamic>))
            .toList() ??
        <FilmDialogue>[]
    ..results = (json['results'] as List<dynamic>?)
            ?.map((r) => WordResult.fromJson(r as Map<String, dynamic>))
            .toList() ??
        <WordResult>[]
    ..boxes = (json['boxes'] as List<dynamic>?)
            ?.map((b) => WordBox.fromJson(b as Map<String, dynamic>))
            .toList() ??
        <WordBox>[]
    ..tags = [...?(json['tags'] as List<dynamic>?)?.cast<String>()]
    ..description = json['description'] as String?
    ..originTags = [...?(json['originTags'] as List<dynamic>?)?.cast<String>()]
    ..topicTags = [...?(json['topicTags'] as List<dynamic>?)?.cast<String>()];

  Map<String, dynamic> toJson() => {
        'sessionId': collectionId,
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
        'dialogues': dialogues.map((d) => d.toJson()).toList(),
        'results': results.map((r) => r.toJson()).toList(),
        'boxes': boxes.map((b) => b.toJson()).toList(),
        'tags': tags,
        if (description != null) 'description': description,
        if (originTags.isNotEmpty) 'originTags': originTags,
        if (topicTags.isNotEmpty) 'topicTags': topicTags,
      };
}
