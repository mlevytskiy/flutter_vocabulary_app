// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photos_with_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sourcesWithWordsHash() => r'6a29c916a0cda937eaea375bd864b97b9ae13efe';

/// The current session's sources with words that the photo panel lists,
/// photos and sets mixed, oldest first by `takenAt` (sources added at the
/// same time keep the order of `WordCollection.sources`), derived in one pass over
/// the rows (sad §4). Only the current session is read, so another session's
/// sources never appear (spec AC-16); a row whose word is cleared does not
/// count (spec AC-15).
///
/// Copied from [sourcesWithWords].
@ProviderFor(sourcesWithWords)
final sourcesWithWordsProvider =
    AutoDisposeProvider<List<SourceWithWords>>.internal(
  sourcesWithWords,
  name: r'sourcesWithWordsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sourcesWithWordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SourcesWithWordsRef = AutoDisposeProviderRef<List<SourceWithWords>>;
String _$photosWithWordsHash() => r'0860e55a8b2da02dbdf17103901679a5f2f7d16b';

/// The current session's photos with words, oldest first: the photos of
/// [sourcesWithWords]. Full-open shows only these (spec AC-21).
///
/// Copied from [photosWithWords].
@ProviderFor(photosWithWords)
final photosWithWordsProvider =
    AutoDisposeProvider<List<PhotoWithWords>>.internal(
  photosWithWords,
  name: r'photosWithWordsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$photosWithWordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PhotosWithWordsRef = AutoDisposeProviderRef<List<PhotoWithWords>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
