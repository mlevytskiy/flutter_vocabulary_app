// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collections_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").

@ProviderFor(CollectionsSearch)
final collectionsSearchProvider = CollectionsSearchFamily._();

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").
final class CollectionsSearchProvider
    extends $NotifierProvider<CollectionsSearch, CollectionsSearchState> {
  /// Holds the Collections screen's search, seeded from the route's tag
  /// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
  /// order (ux-flows, "SCR-05 sort when opened from a tag").
  CollectionsSearchProvider._(
      {required CollectionsSearchFamily super.from,
      required (
        TagKind?,
        String?,
      )
          super.argument})
      : super(
          retry: null,
          name: r'collectionsSearchProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionsSearchHash();

  @override
  String toString() {
    return r'collectionsSearchProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CollectionsSearch create() => CollectionsSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionsSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionsSearchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionsSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionsSearchHash() => r'09e159adf95b570fc07e905e6b18acc06625b774';

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").

final class CollectionsSearchFamily extends $Family
    with
        $ClassFamilyOverride<
            CollectionsSearch,
            CollectionsSearchState,
            CollectionsSearchState,
            CollectionsSearchState,
            (
              TagKind?,
              String?,
            )> {
  CollectionsSearchFamily._()
      : super(
          retry: null,
          name: r'collectionsSearchProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Holds the Collections screen's search, seeded from the route's tag
  /// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
  /// order (ux-flows, "SCR-05 sort when opened from a tag").

  CollectionsSearchProvider call(
    TagKind? tagKind,
    String? tag,
  ) =>
      CollectionsSearchProvider._(argument: (
        tagKind,
        tag,
      ), from: this);

  @override
  String toString() => r'collectionsSearchProvider';
}

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").

abstract class _$CollectionsSearch extends $Notifier<CollectionsSearchState> {
  late final _$args = ref.$arg as (
    TagKind?,
    String?,
  );
  TagKind? get tagKind => _$args.$1;
  String? get tag => _$args.$2;

  CollectionsSearchState build(
    TagKind? tagKind,
    String? tag,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<CollectionsSearchState, CollectionsSearchState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CollectionsSearchState, CollectionsSearchState>,
        CollectionsSearchState,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args.$1,
              _$args.$2,
            ));
  }
}
