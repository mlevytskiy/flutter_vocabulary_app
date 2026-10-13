// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_run_tracker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$storyRunTrackerHash() => r'cd4a625b54f3afee1aacb12f72ff163459cbe7d4';

/// Starts story runs, follows them on the Worker and collects their results to
/// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
///
/// A run is saved before it is started, so a closed app finds it again and
/// collects it without starting it twice (AC-10). Nothing here throws.
///
/// Copied from [StoryRunTracker].
@ProviderFor(StoryRunTracker)
final storyRunTrackerProvider =
    NotifierProvider<StoryRunTracker, StoryTrackerState>.internal(
  StoryRunTracker.new,
  name: r'storyRunTrackerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storyRunTrackerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StoryRunTracker = Notifier<StoryTrackerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
