import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_collection.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/story/word_grouping.dart';
import '../../word_input/word_input_notifier.dart';

part 'exercise_words.g.dart';

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [collectionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.
@riverpod
Future<({List<WordPair> group, List<WordPair> others})> exerciseWords(
    Ref ref, String? collectionId, String groupId) async {
  final WordCollection? collection = collectionId == null
      ? await ref.watch(wordInputNotifierProvider.future)
      : await ref.watch(collectionByIdProvider(collectionId).future);
  if (collection == null) return (group: const <WordPair>[], others: const <WordPair>[]);
  final group = collection.groups.where((g) => g.id == groupId).firstOrNull;
  final words = group == null ? const <WordPair>[] : groupWords(collection, group);
  final inGroup = {for (final w in words) w.rowId};
  return (
    group: words,
    others: [for (final w in wordsToLearn(collection)) if (!inGroup.contains(w.rowId)) w],
  );
}

/// The film dialogues of the session an exercise reads, same session choice as
/// [exerciseWords] (null = current, id = History). S-31.
@riverpod
Future<List<FilmDialogue>> exerciseDialogues(Ref ref, String? collectionId) async {
  final WordCollection? collection = collectionId == null
      ? await ref.watch(wordInputNotifierProvider.future)
      : await ref.watch(collectionByIdProvider(collectionId).future);
  return collection?.dialogues ?? const <FilmDialogue>[];
}
