// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sourceTagSuggestionsHash() =>
    r'a66486dfc7e25245927f30a4d82759e33ac7d1d2';

/// The tags already used on sources (a photo, a set, a film) in every
/// session, most used first: what the Notes page suggests for a source's
/// tag (notes-editing, owner 2026-10-15). Session tags are a separate pool.
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
String _$sessionTagSuggestionsHash() =>
    r'710a79d4c8d2b123c6c7b0ab7ecab3d179592ba0';

/// The tags already given to whole sessions, most used first.
///
/// Copied from [sessionTagSuggestions].
@ProviderFor(sessionTagSuggestions)
final sessionTagSuggestionsProvider =
    AutoDisposeProvider<List<String>>.internal(
  sessionTagSuggestions,
  name: r'sessionTagSuggestionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionTagSuggestionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SessionTagSuggestionsRef = AutoDisposeProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
