// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tagSuggestionsHash() => r'8d71a9b62454ce38a596798f13d5c4b5f47a4c14';

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

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.
///
/// Copied from [tagSuggestions].
@ProviderFor(tagSuggestions)
const tagSuggestionsProvider = TagSuggestionsFamily();

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.
///
/// Copied from [tagSuggestions].
class TagSuggestionsFamily extends Family<List<TagSuggestion>> {
  /// The suggestions for a tag field of [kind] matching [query] (AC-35): the
  /// tag library ranked by use in the live collections, then the presets.
  /// Tags already on the field are not removed here; the widgets filter them.
  ///
  /// Copied from [tagSuggestions].
  const TagSuggestionsFamily();

  /// The suggestions for a tag field of [kind] matching [query] (AC-35): the
  /// tag library ranked by use in the live collections, then the presets.
  /// Tags already on the field are not removed here; the widgets filter them.
  ///
  /// Copied from [tagSuggestions].
  TagSuggestionsProvider call(
    TagKind kind, {
    String query = '',
  }) {
    return TagSuggestionsProvider(
      kind,
      query: query,
    );
  }

  @override
  TagSuggestionsProvider getProviderOverride(
    covariant TagSuggestionsProvider provider,
  ) {
    return call(
      provider.kind,
      query: provider.query,
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
  String? get name => r'tagSuggestionsProvider';
}

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.
///
/// Copied from [tagSuggestions].
class TagSuggestionsProvider extends AutoDisposeProvider<List<TagSuggestion>> {
  /// The suggestions for a tag field of [kind] matching [query] (AC-35): the
  /// tag library ranked by use in the live collections, then the presets.
  /// Tags already on the field are not removed here; the widgets filter them.
  ///
  /// Copied from [tagSuggestions].
  TagSuggestionsProvider(
    TagKind kind, {
    String query = '',
  }) : this._internal(
          (ref) => tagSuggestions(
            ref as TagSuggestionsRef,
            kind,
            query: query,
          ),
          from: tagSuggestionsProvider,
          name: r'tagSuggestionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$tagSuggestionsHash,
          dependencies: TagSuggestionsFamily._dependencies,
          allTransitiveDependencies:
              TagSuggestionsFamily._allTransitiveDependencies,
          kind: kind,
          query: query,
        );

  TagSuggestionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.kind,
    required this.query,
  }) : super.internal();

  final TagKind kind;
  final String query;

  @override
  Override overrideWith(
    List<TagSuggestion> Function(TagSuggestionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TagSuggestionsProvider._internal(
        (ref) => create(ref as TagSuggestionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        kind: kind,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<TagSuggestion>> createElement() {
    return _TagSuggestionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TagSuggestionsProvider &&
        other.kind == kind &&
        other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, kind.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TagSuggestionsRef on AutoDisposeProviderRef<List<TagSuggestion>> {
  /// The parameter `kind` of this provider.
  TagKind get kind;

  /// The parameter `query` of this provider.
  String get query;
}

class _TagSuggestionsProviderElement
    extends AutoDisposeProviderElement<List<TagSuggestion>>
    with TagSuggestionsRef {
  _TagSuggestionsProviderElement(super.provider);

  @override
  TagKind get kind => (origin as TagSuggestionsProvider).kind;
  @override
  String get query => (origin as TagSuggestionsProvider).query;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
