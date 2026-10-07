import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';

/// Test doubles for the learn page's grouping state (mnemonic-story T16), so a
/// widget test needs neither Isar nor the Worker.

/// A word-groups notifier whose state the test sets; it records what the
/// screens ask of it.
class FakeGroups extends WordGroupsNotifier {
  FakeGroups(this.initial);
  final WordGroupsState initial;
  int ensured = 0;
  final List<String> selected = [];

  @override
  WordGroupsState build(String? sessionId) => initial;

  @override
  Future<void> ensureGrouped() async => ensured++;

  @override
  Future<void> select(String groupId) async {
    selected.add(groupId);
    state = WordGroupsState(
      status: state.status,
      groups: state.groups,
      selectedGroupId: groupId,
    );
  }
}

class FakeTracker extends StoryRunTracker {
  FakeTracker(this.initial);
  final StoryTrackerState initial;

  @override
  StoryTrackerState build() => initial;
}

/// The overrides a screen that shows the learn page needs: one selected group
/// and no refusals.
List<Override> fakeGroupOverrides([FakeGroups? groups]) => [
      wordGroupsNotifierProvider(null).overrideWith(() =>
          groups ??
          FakeGroups(WordGroupsState(groups: [_all], selectedGroupId: 'all'))),
      storyRunTrackerProvider
          .overrideWith(() => FakeTracker(const StoryTrackerState())),
    ];

final _all = WordGroup()
  ..id = 'all'
  ..name = 'All words';
