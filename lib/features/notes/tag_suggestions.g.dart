// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sourceTagSuggestionsHash() =>
    r'92b3cde18c778350a6f940b33186d3d0519e439b';

/// The tags already used on sources (a photo, a set, a film) in every
/// session, most used first: what the Notes page suggests for a source's
/// tag (notes-editing, owner 2026-10-15). A collection's own tags are a separate pool.
///
/// Copied from [sourceTagSuggestions].
@ProviderFor(sourceTagSuggestions)
final sourceTagSuggestionsProvider = AutoDisposeProvider<List<String>>.internal(
  sourceTagSuggestions,
  name: r'sourceTagSuggestionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sourceTagSuggestionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SourceTagSuggestionsRef = AutoDisposeProviderRef<List<String>>;
String _$collectionTagSuggestionsHash() =>
    r'0bfe698980004241d0069cc765a91259f51f4c16';

/// The tags already given to whole sessions, most used first.
///
/// Copied from [collectionTagSuggestions].
@ProviderFor(collectionTagSuggestions)
final collectionTagSuggestionsProvider =
    AutoDisposeProvider<List<String>>.internal(
  collectionTagSuggestions,
  name: r'collectionTagSuggestionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionTagSuggestionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CollectionTagSuggestionsRef = AutoDisposeProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
