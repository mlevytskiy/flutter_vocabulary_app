/// The pure tag rules of collection-tags (sad §5, §8).
///
/// Plain strings, lists and records only — no Flutter, no Isar — so
/// `CollectionStore` can call them inside its transactions (the migration, the
/// library writes) and the tag field can call them while typing, and they test
/// without either. A tag is (kind, text): within a kind two spellings that
/// differ only by case are one tag, and the first spelling stored wins.
library;

import '../models/tag_kind.dart';

/// A kind's list takes a new tag only while it holds fewer than this many.
const maxTagsPerKind = 10;

/// The longest new tag, in characters.
const maxTagLength = 30;

/// The most suggestions a field shows (spec §6).
const maxSuggestions = 8;

/// Shown under a field when [tagProblem] refuses a tag (AC-04).
const tagProblemMessage = 'A tag is 1 to 30 characters on one line';

/// Shown under a field when [canAddTag] says no (AC-10).
const tagLimitMessage = 'A collection holds at most 10 tags of each kind';

/// The preset origin tags, in the order they are offered (AC-31).
const originPresets = <String>[
  'Book',
  'Film',
  'Series',
  'Cartoon',
  'Song',
  'Podcast',
  'YouTube',
  'Social media',
  'Article',
  'News',
  'Textbook',
  'Course',
  'Lesson',
  'Quizlet',
  'Game',
  'Conversation',
  'Travel',
];

/// The preset topic tags, in the order they are offered (AC-31).
const topicPresets = <String>[
  'Everyday life',
  'Food',
  'Travel',
  'Work',
  'Business',
  'IT',
  'Health',
  'Sport',
  'Nature',
  'Home',
  'Shopping',
  'Money',
  'People',
  'Emotions',
  'Education',
  'Phrasal verbs',
  'Idioms',
  'Slang',
  'Grammar',
  'Exam prep',
];

/// The presets of [kind].
List<String> presetsFor(TagKind kind) =>
    kind == TagKind.origin ? originPresets : topicPresets;

final _lineBreak = RegExp(r'[\r\n  ]');

/// What is wrong with [text] as a new tag, or null when it is fine (AC-04):
/// after trimming it must be 1 to [maxTagLength] characters on one line.
/// Tags stored before the update are not checked (AC-17b).
String? tagProblem(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty ||
      trimmed.runes.length > maxTagLength ||
      _lineBreak.hasMatch(trimmed)) {
    return tagProblemMessage;
  }
  return null;
}

/// The identity of a tag within its kind: trimmed and lower-cased.
String tagKey(String text) => text.trim().toLowerCase();

/// Whether a list of [tags] of one kind still takes a new tag (AC-10).
/// A migrated list may already hold more than [maxTagsPerKind] (AC-17b).
bool canAddTag(List<String> tags) => tags.length < maxTagsPerKind;

/// [text] added to the end of [tags], without changing [tags]. On a `problem`
/// ([tagProblemMessage] or [tagLimitMessage]) the returned `tags` are [tags]
/// unchanged. A tag already there ignoring case adds nothing and is no
/// problem. The spelling kept is the first of [knownSpellings] with the same
/// key (the tag library, then the presets: AC-09, AC-35), else the trimmed
/// text as typed.
({List<String> tags, String? problem}) addTag(
  List<String> tags,
  String text, {
  Iterable<String> knownSpellings = const [],
}) {
  final problem = tagProblem(text);
  if (problem != null) return (tags: tags, problem: problem);
  final key = tagKey(text);
  if (tags.any((t) => tagKey(t) == key)) return (tags: tags, problem: null);
  if (!canAddTag(tags)) return (tags: tags, problem: tagLimitMessage);
  final spelling = knownSpellings.firstWhere(
    (s) => tagKey(s) == key,
    orElse: () => text.trim(),
  );
  return (tags: [...tags, spelling], problem: null);
}

/// Sorts the untyped tags from before the update into the two kinds
/// (AC-31): a tag matching an origin preset ignoring case is an origin tag,
/// every other is a topic tag. Spellings and order are kept and nothing is
/// dropped or cut; call [mergeCaseDuplicates] on each list afterwards.
({List<String> origin, List<String> topic}) sortLegacyTags(
  List<String> tags,
) {
  final originKeys = {for (final p in originPresets) tagKey(p)};
  final origin = <String>[];
  final topic = <String>[];
  for (final tag in tags) {
    (originKeys.contains(tagKey(tag)) ? origin : topic).add(tag);
  }
  return (origin: origin, topic: topic);
}

/// [tags] with spellings that differ only by case merged into the first one
/// (AC-17b, AC-32), the order kept.
List<String> mergeCaseDuplicates(List<String> tags) {
  final seen = <String>{};
  return [
    for (final tag in tags)
      if (seen.add(tagKey(tag))) tag,
  ];
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Whether [query] matches the start of [text] or of any word in it, ignoring
/// case and spaces around the query (AC-08, AC-35): "co" matches "Cooking" and
/// "Home cooking" but not "Tacos". A word starts after any character that is
/// not a letter or digit. An empty query matches everything.
bool matchesWordStart(String text, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final lower = text.toLowerCase();
  for (var i = lower.indexOf(q); i >= 0; i = lower.indexOf(q, i + 1)) {
    if (i == 0 || !_wordChar.hasMatch(lower[i - 1])) return true;
  }
  return false;
}

/// One tag of the tag library as plain values: what `TagLibraryEntry` holds,
/// without Isar. [lastUsedAt] is null for a tag the migration put there.
typedef LibraryTag = ({
  TagKind kind,
  String text,
  DateTime? lastUsedAt,
  bool forgotten,
});

/// A suggestion: the `text` to offer and whether it is a preset (a preset has
/// no "Forget this tag").
typedef TagSuggestion = ({String text, bool isPreset});

/// The suggestions for a field of [kind] (AC-35, AC-18, AC-12), at most
/// [limit]. Library tags of the kind that match [query] by word start come
/// first: those in use, the most collections first ([counts] maps a tag's key
/// to the number of collections using it, a collection and its sources
/// counting once, binned ones not at all), ties by the latest `lastUsedAt`;
/// then the library tags in use nowhere, latest first. Then the [presets]
/// that match and are not in the library. A forgotten tag is never offered
/// (and does not hide a preset of the same key); a tag already in [added] is
/// left out, ignoring case.
List<TagSuggestion> rankSuggestions({
  required TagKind kind,
  required Iterable<LibraryTag> library,
  required Map<String, int> counts,
  required Iterable<String> presets,
  required Iterable<String> added,
  required String query,
  int limit = maxSuggestions,
}) {
  final taken = {for (final t in added) tagKey(t)};
  final libraryKeys = <String>{};
  final inUse = <LibraryTag>[];
  final unused = <LibraryTag>[];
  for (final entry in library) {
    if (entry.kind != kind || entry.forgotten) continue;
    final key = tagKey(entry.text);
    if (!libraryKeys.add(key) || taken.contains(key)) continue;
    if (!matchesWordStart(entry.text, query)) continue;
    ((counts[key] ?? 0) > 0 ? inUse : unused).add(entry);
  }

  // Latest first; a tag never added by the learner (null) after all dated ones.
  int latest(LibraryTag a, LibraryTag b) {
    final x = a.lastUsedAt, y = b.lastUsedAt;
    if (x != null && y != null) return y.compareTo(x);
    if (x != null) return -1;
    if (y != null) return 1;
    return a.text.toLowerCase().compareTo(b.text.toLowerCase());
  }

  inUse.sort((a, b) {
    final byCount = counts[tagKey(b.text)]!.compareTo(counts[tagKey(a.text)]!);
    return byCount != 0 ? byCount : latest(a, b);
  });
  unused.sort(latest);

  return [
    for (final e in [...inUse, ...unused]) (text: e.text, isPreset: false),
    for (final p in presets)
      if (!libraryKeys.contains(tagKey(p)) &&
          !taken.contains(tagKey(p)) &&
          matchesWordStart(p, query))
        (text: p, isPreset: true),
  ].take(limit).toList();
}
