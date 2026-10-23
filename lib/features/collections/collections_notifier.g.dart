// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collections_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the open folder of the Collections screen (collections-screen T15).

@ProviderFor(CollectionsNotifier)
final collectionsProvider = CollectionsNotifierProvider._();

/// Holds the open folder of the Collections screen (collections-screen T15).
final class CollectionsNotifierProvider
    extends $NotifierProvider<CollectionsNotifier, CollectionsState> {
  /// Holds the open folder of the Collections screen (collections-screen T15).
  CollectionsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionsNotifierHash();

  @$internal
  @override
  CollectionsNotifier create() => CollectionsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionsState>(value),
    );
  }
}

String _$collectionsNotifierHash() =>
    r'4ad16935bf13243d97ed042bf5af161115e3a04a';

/// Holds the open folder of the Collections screen (collections-screen T15).

abstract class _$CollectionsNotifier extends $Notifier<CollectionsState> {
  CollectionsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CollectionsState, CollectionsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CollectionsState, CollectionsState>,
        CollectionsState,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
