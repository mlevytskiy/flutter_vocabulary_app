// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collections_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$collectionsSearchHash() => r'09e159adf95b570fc07e905e6b18acc06625b774';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$CollectionsSearch
    extends BuildlessAutoDisposeNotifier<CollectionsSearchState> {
  late final TagKind? tagKind;
  late final String? tag;

  CollectionsSearchState build(
    TagKind? tagKind,
    String? tag,
  );
}

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").
///
/// Copied from [CollectionsSearch].
@ProviderFor(CollectionsSearch)
const collectionsSearchProvider = CollectionsSearchFamily();

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").
///
/// Copied from [CollectionsSearch].
class CollectionsSearchFamily extends Family<CollectionsSearchState> {
  /// Holds the Collections screen's search, seeded from the route's tag
  /// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
  /// order (ux-flows, "SCR-05 sort when opened from a tag").
  ///
  /// Copied from [CollectionsSearch].
  const CollectionsSearchFamily();

  /// Holds the Collections screen's search, seeded from the route's tag
  /// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
  /// order (ux-flows, "SCR-05 sort when opened from a tag").
  ///
  /// Copied from [CollectionsSearch].
  CollectionsSearchProvider call(
    TagKind? tagKind,
    String? tag,
  ) {
    return CollectionsSearchProvider(
      tagKind,
      tag,
    );
  }

  @override
  CollectionsSearchProvider getProviderOverride(
    covariant CollectionsSearchProvider provider,
  ) {
    return call(
      provider.tagKind,
      provider.tag,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'collectionsSearchProvider';
}

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").
///
/// Copied from [CollectionsSearch].
class CollectionsSearchProvider extends AutoDisposeNotifierProviderImpl<
    CollectionsSearch, CollectionsSearchState> {
  /// Holds the Collections screen's search, seeded from the route's tag
  /// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
  /// order (ux-flows, "SCR-05 sort when opened from a tag").
  ///
  /// Copied from [CollectionsSearch].
  CollectionsSearchProvider(
    TagKind? tagKind,
    String? tag,
  ) : this._internal(
          () => CollectionsSearch()
            ..tagKind = tagKind
            ..tag = tag,
          from: collectionsSearchProvider,
          name: r'collectionsSearchProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$collectionsSearchHash,
          dependencies: CollectionsSearchFamily._dependencies,
          allTransitiveDependencies:
              CollectionsSearchFamily._allTransitiveDependencies,
          tagKind: tagKind,
          tag: tag,
        );

  CollectionsSearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.tagKind,
    required this.tag,
  }) : super.internal();

  final TagKind? tagKind;
  final String? tag;

  @override
  CollectionsSearchState runNotifierBuild(
    covariant CollectionsSearch notifier,
  ) {
    return notifier.build(
      tagKind,
      tag,
    );
  }

  @override
  Override overrideWith(CollectionsSearch Function() create) {
    return ProviderOverride(
      origin: this,
      override: CollectionsSearchProvider._internal(
        () => create()
          ..tagKind = tagKind
          ..tag = tag,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        tagKind: tagKind,
        tag: tag,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<CollectionsSearch, CollectionsSearchState>
      createElement() {
    return _CollectionsSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionsSearchProvider &&
        other.tagKind == tagKind &&
        other.tag == tag;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, tagKind.hashCode);
    hash = _SystemHash.combine(hash, tag.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CollectionsSearchRef
    on AutoDisposeNotifierProviderRef<CollectionsSearchState> {
  /// The parameter `tagKind` of this provider.
  TagKind? get tagKind;

  /// The parameter `tag` of this provider.
  String? get tag;
}

class _CollectionsSearchProviderElement
    extends AutoDisposeNotifierProviderElement<CollectionsSearch,
        CollectionsSearchState> with CollectionsSearchRef {
  _CollectionsSearchProviderElement(super.provider);

  @override
  TagKind? get tagKind => (origin as CollectionsSearchProvider).tagKind;
  @override
  String? get tag => (origin as CollectionsSearchProvider).tag;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
