import 'dart:math';

import '../models/session.dart';
import '../models/word_group.dart';
import '../models/word_pair.dart';

/// The pure grouping rules of the learn page (mnemonic-story, ADR-0005; sad §6
/// S-01 and S-08). No Worker, no Isar store: everything here is a function over
/// a [Session] the caller already holds. Only the topical split of the words
/// needs an AI; the caller asks the Worker for it when [planGrouping] says
/// [GroupingAsk], then hands the answer to [applySplit].

/// Above this many words to learn a session is split into groups of
/// [minGroupSize] to [maxGroupSize]; at or below it the session is one group.
const int maxGroupSize = 19;
const int minGroupSize = 7;

/// The name of a small session's only group (AC-02).
const String allWordsName = 'All words';

/// The name of the group the words added beside a story group form (AC-02b).
const String newWordsName = 'New words';

/// The session's words to learn: a row with an English word plus a translation
/// or a definition (learn-part-step-1). A row with no [WordPair.rowId] cannot
/// belong to a group and is left out.
List<WordPair> wordsToLearn(Session session) =>
    session.words.where((w) => w.isFilled && w.rowId.isNotEmpty).toList();

/// What the words looked like when grouping last ran: the row id and the
/// English word of each word to learn, whatever the row order. A translation or
/// definition edit leaves it unchanged (AC-03).
String groupedWordsKey(Session session) {
  final entries = [
    for (final w in wordsToLearn(session)) '${w.rowId}\t${w.word.trim()}',
  ]..sort();
  return entries.join('\n');
}

/// A word sent to the Worker for the split.
class GroupingWord {
  final String rowId;
  final String word;
  const GroupingWord(this.rowId, this.word);
}

sealed class GroupingPlan {
  const GroupingPlan();
}

/// The words to learn did not change since the last grouping: nothing to do.
class GroupingUnchanged extends GroupingPlan {
  const GroupingUnchanged();
}

/// Grouping settled without the Worker. [groups] is the session's new group
/// list; [waiting] holds the row ids of words that belong to no group yet
/// (AC-05).
class GroupingLocal extends GroupingPlan {
  final List<WordGroup> groups;
  final List<String> waiting;
  const GroupingLocal(this.groups, this.waiting);
}

/// The Worker must split [words]; [keep] are the groups without a story, which
/// keep their id, name and words and may only gain words (AC-05).
class GroupingAsk extends GroupingPlan {
  final List<GroupingWord> words;
  final List<WordGroup> keep;
  const GroupingAsk(this.words, this.keep);
}

/// One group of the Worker's answer; [id] is set only for a kept group.
class SplitGroup {
  final String? id;
  final String name;
  final List<String> rowIds;
  const SplitGroup({this.id, required this.name, required this.rowIds});

  factory SplitGroup.fromJson(Map<String, dynamic> json) => SplitGroup(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        rowIds: [...(json['rowIds'] as List<dynamic>? ?? const []).cast<String>()],
      );
}

sealed class SplitResult {
  const SplitResult();
}

/// A valid split: the session's complete new group list and the row ids that
/// wait for a group.
class SplitOk extends SplitResult {
  final List<WordGroup> groups;
  final List<String> waiting;
  const SplitOk(this.groups, this.waiting);
}

/// The split dropped or doubled a word, broke a kept group or had a group
/// outside 7 to 19 (AC-04).
class SplitInvalid extends SplitResult {
  const SplitInvalid();
}

/// Decides how the session is grouped again. [runsInProgress] holds the ids of
/// groups whose story run is going: they count as groups with a story, so their
/// words never change (AC-05).
GroupingPlan planGrouping(
  Session session, [
  Set<String> runsInProgress = const {},
  String Function()? newId,
]) {
  if (session.groupedWordsKey == groupedWordsKey(session)) {
    return const GroupingUnchanged();
  }
  final basis = _Basis(session, runsInProgress);
  final make = newId ?? _randomId;

  if (basis.learn.length <= maxGroupSize) {
    // AC-02 / AC-02b: a small session needs no AI.
    if (basis.free.isEmpty) return GroupingLocal(basis.storyGroups, const []);
    final hasStory = basis.storyGroups.isNotEmpty;
    final reused = basis.others.isEmpty ? null : basis.others.first;
    final own = WordGroup()
      ..id = reused?.id ?? make()
      ..name = hasStory ? newWordsName : allWordsName
      ..rowIds = [for (final w in basis.free) w.rowId];
    return GroupingLocal([...basis.storyGroups, own], const []);
  }

  final newWords = basis.newWords;
  if (newWords.isEmpty) {
    return GroupingLocal(basis.groupsIn(basis.keeps, const []), const []);
  }
  final room = basis.keeps.fold<int>(0, (n, g) => n + maxGroupSize - g.rowIds.length);
  if (newWords.length < minGroupSize && room <= 0) {
    // Nothing can take them and they cannot make a group: they wait (AC-05).
    return GroupingLocal(basis.groupsIn(basis.keeps, const []),
        [for (final w in newWords) w.rowId]);
  }
  return GroupingAsk(
    [
      for (final g in basis.keeps)
        for (final id in g.rowIds) GroupingWord(id, basis.byId[id]!.word.trim()),
      for (final w in newWords) GroupingWord(w.rowId, w.word.trim()),
    ],
    basis.keeps,
  );
}

/// Checks the Worker's [split] against the session and, when valid, returns the
/// session's new groups: every word to place exactly once, new groups of 7 to
/// 19, kept groups with their id, name and words plus the words they gained, and
/// fewer than 7 left-over words waiting (AC-04, AC-05). [runsInProgress] must be
/// the same set given to [planGrouping].
SplitResult applySplit(
  Session session,
  List<SplitGroup> split, [
  Set<String> runsInProgress = const {},
  String Function()? newId,
]) {
  final basis = _Basis(session, runsInProgress);
  if (basis.learn.length <= maxGroupSize || basis.newWords.isEmpty) {
    return const SplitInvalid();
  }
  final make = newId ?? _randomId;
  final keepById = {for (final g in basis.keeps) g.id: g};
  final newWordIds = {for (final w in basis.newWords) w.rowId};
  final placeable = {...newWordIds, for (final g in basis.keeps) ...g.rowIds};

  final seenWords = <String>{};
  final seenKeeps = <String>{};
  final gained = <String, List<String>>{};
  final fresh = <SplitGroup>[];
  for (final g in split) {
    for (final id in g.rowIds) {
      if (!placeable.contains(id) || !seenWords.add(id)) return const SplitInvalid();
    }
    final keepId = g.id;
    if (keepId == null) {
      fresh.add(g);
      continue;
    }
    final kept = keepById[keepId];
    if (kept == null || !seenKeeps.add(keepId)) return const SplitInvalid();
    final ids = g.rowIds.toSet();
    if (!kept.rowIds.every(ids.contains)) return const SplitInvalid();
    final added = [for (final id in g.rowIds) if (!kept.rowIds.contains(id)) id];
    if (kept.rowIds.length + added.length > maxGroupSize) return const SplitInvalid();
    gained[keepId] = added;
  }
  if (seenWords.length != placeable.length) return const SplitInvalid();
  if (seenKeeps.length != keepById.length) return const SplitInvalid();

  final waiting = <String>[];
  final created = <WordGroup>[];
  for (final g in fresh) {
    final size = g.rowIds.length;
    if (size > maxGroupSize) return const SplitInvalid();
    if (size == 0) return const SplitInvalid();
    if (size < minGroupSize) {
      // Only words that could not make a group on their own may wait.
      if (basis.newWords.length >= minGroupSize) return const SplitInvalid();
      waiting.addAll(g.rowIds);
      continue;
    }
    final name = g.name.trim();
    created.add(WordGroup()
      ..id = make()
      ..name = name.isEmpty ? 'Words' : name
      ..rowIds = [...g.rowIds]);
  }
  if (waiting.length >= minGroupSize) return const SplitInvalid();

  return SplitOk([
    ...basis.groupsIn(basis.keeps, const [], gained: gained),
    ...created,
  ], waiting);
}

/// The group's current words, by row id: a deleted word is gone and an edited
/// word shows its new form (AC-17). A row that stopped being a word to learn
/// is gone too.
List<WordPair> groupWords(Session session, WordGroup group) {
  final byId = {for (final w in wordsToLearn(session)) w.rowId: w};
  return [
    for (final id in group.rowIds)
      if (byId[id] != null) byId[id]!,
  ];
}

/// True when the group has a story and its English words are no longer the ones
/// the story was made from (AC-17). A translation or definition edit does not
/// count.
bool isOutdated(Session session, WordGroup group) {
  if (group.storyRunId == null) return false;
  final now = [for (final w in groupWords(session, group)) w.word.trim()]..sort();
  final then = [for (final w in group.storyWords) w.trim()]..sort();
  if (now.length != then.length) return true;
  for (var i = 0; i < now.length; i++) {
    if (now[i] != then[i]) return true;
  }
  return false;
}

/// The group the learn page shows as selected: the remembered one, else the
/// first, else none (AC-01).
String? selectedGroupIdOf(Session session) {
  for (final g in session.groups) {
    if (g.id == session.selectedGroupId) return g.id;
  }
  return session.groups.isEmpty ? null : session.groups.first.id;
}

/// A group has a story, or a run going, and so never changes its words.
bool _isStoryGroup(WordGroup g, Set<String> runsInProgress) =>
    g.storyRunId != null || runsInProgress.contains(g.id);

class _Basis {
  final Session session;
  final Set<String> runsInProgress;
  late final List<WordPair> learn = wordsToLearn(session);
  late final Map<String, WordPair> byId = {for (final w in learn) w.rowId: w};

  /// Groups with a story or a run, following their words (a word that left is
  /// dropped); a group left with no words is dropped.
  late final List<WordGroup> storyGroups = [
    for (final g in session.groups)
      if (_isStoryGroup(g, runsInProgress)) _follow(g),
  ].where((g) => g.rowIds.isNotEmpty).toList();

  /// Groups without a story, as the session holds them.
  late final List<WordGroup> others = [
    for (final g in session.groups)
      if (!_isStoryGroup(g, runsInProgress)) g,
  ];

  late final Set<String> _storyIds = {
    for (final g in storyGroups) ...g.rowIds,
  };

  /// Words to learn outside every group with a story.
  late final List<WordPair> free =
      [for (final w in learn) if (!_storyIds.contains(w.rowId)) w];

  /// Groups without a story that stay (for a session above 19 words): they keep
  /// their id and name and lose only words that left. One shrunk below 7 or
  /// holding a word twice is dissolved; its words are free again.
  late final List<WordGroup> keeps = () {
    final out = <WordGroup>[];
    final taken = <String>{};
    for (final g in others) {
      final ids = [
        for (final id in g.rowIds)
          if (byId.containsKey(id) && !_storyIds.contains(id) && !taken.contains(id)) id,
      ];
      if (ids.length < minGroupSize || ids.length > maxGroupSize) continue;
      taken.addAll(ids);
      out.add(g.copy()..rowIds = ids);
    }
    return out;
  }();

  /// Free words no kept group holds.
  late final List<WordPair> newWords = () {
    final held = {for (final g in keeps) ...g.rowIds};
    return [for (final w in free) if (!held.contains(w.rowId)) w];
  }();

  _Basis(this.session, this.runsInProgress);

  WordGroup _follow(WordGroup g) =>
      g.copy()..rowIds = [for (final id in g.rowIds) if (byId.containsKey(id)) id];

  /// The session's groups in their old order: story groups (following their
  /// words), then the [kept] ones with what each gained.
  List<WordGroup> groupsIn(
    List<WordGroup> kept,
    List<WordGroup> extra, {
    Map<String, List<String>> gained = const {},
  }) {
    final keptById = {for (final g in kept) g.id: g};
    final storyById = {for (final g in storyGroups) g.id: g};
    final out = <WordGroup>[];
    for (final g in session.groups) {
      final s = storyById[g.id];
      if (s != null) {
        out.add(s);
        continue;
      }
      final k = keptById[g.id];
      if (k != null) out.add(k.copy()..rowIds = [...k.rowIds, ...?gained[k.id]]);
    }
    return [...out, ...extra];
  }
}

final Random _random = Random.secure();

String _randomId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}
