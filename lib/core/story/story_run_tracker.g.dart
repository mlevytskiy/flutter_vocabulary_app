// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_run_tracker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Starts story runs, follows them on the Worker and collects their results to
/// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
///
/// A run is saved before it is started, so a closed app finds it again and
/// collects it without starting it twice (AC-10). Nothing here throws.

@ProviderFor(StoryRunTracker)
final storyRunTrackerProvider = StoryRunTrackerProvider._();

/// Starts story runs, follows them on the Worker and collects their results to
/// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
///
/// A run is saved before it is started, so a closed app finds it again and
/// collects it without starting it twice (AC-10). Nothing here throws.
final class StoryRunTrackerProvider
    extends $NotifierProvider<StoryRunTracker, StoryTrackerState> {
  /// Starts story runs, follows them on the Worker and collects their results to
  /// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
  ///
  /// A run is saved before it is started, so a closed app finds it again and
  /// collects it without starting it twice (AC-10). Nothing here throws.
  StoryRunTrackerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storyRunTrackerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storyRunTrackerHash();

  @$internal
  @override
  StoryRunTracker create() => StoryRunTracker();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoryTrackerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoryTrackerState>(value),
    );
  }
}

String _$storyRunTrackerHash() => r'9d4d163394fdcd54096adf6141deb776a2901938';

/// Starts story runs, follows them on the Worker and collects their results to
/// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
///
/// A run is saved before it is started, so a closed app finds it again and
/// collects it without starting it twice (AC-10). Nothing here throws.

abstract class _$StoryRunTracker extends $Notifier<StoryTrackerState> {
  StoryTrackerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StoryTrackerState, StoryTrackerState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<StoryTrackerState, StoryTrackerState>,
        StoryTrackerState,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
