// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.

@ProviderFor(tagSuggestions)
final tagSuggestionsProvider = TagSuggestionsFamily._();

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.

final class TagSuggestionsProvider extends $FunctionalProvider<
    List<TagSuggestion>,
    List<TagSuggestion>,
    List<TagSuggestion>> with $Provider<List<TagSuggestion>> {
  /// The suggestions for a tag field of [kind] matching [query] (AC-35): the
  /// tag library ranked by use in the live collections, then the presets.
  /// Tags already on the field are not removed here; the widgets filter them.
  TagSuggestionsProvider._(
      {required TagSuggestionsFamily super.from,
      required (
        TagKind, {
        String query,
      })
          super.argument})
      : super(
          retry: null,
          name: r'tagSuggestionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tagSuggestionsHash();

  @override
  String toString() {
    return r'tagSuggestionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<List<TagSuggestion>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<TagSuggestion> create(Ref ref) {
    final argument = this.argument as (
      TagKind, {
      String query,
    });
    return tagSuggestions(
      ref,
      argument.$1,
      query: argument.query,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TagSuggestion> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TagSuggestion>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TagSuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tagSuggestionsHash() => r'e1f07b750a2b1d22d7a5682ec94807399d808a6a';

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.

final class TagSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
            List<TagSuggestion>,
            (
              TagKind, {
              String query,
            })> {
  TagSuggestionsFamily._()
      : super(
          retry: null,
          name: r'tagSuggestionsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The suggestions for a tag field of [kind] matching [query] (AC-35): the
  /// tag library ranked by use in the live collections, then the presets.
  /// Tags already on the field are not removed here; the widgets filter them.

  TagSuggestionsProvider call(
    TagKind kind, {
    String query = '',
  }) =>
      TagSuggestionsProvider._(argument: (
        kind,
        query: query,
      ), from: this);

  @override
  String toString() => r'tagSuggestionsProvider';
}
