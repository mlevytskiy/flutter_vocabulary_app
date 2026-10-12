// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photos_with_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$photosWithWordsHash() => r'83416b42c77474cd8508e15eb43fd30a0fe7b609';

/// The current session's photos with words, oldest first (the order of
/// `Session.sources`), derived in one pass over the rows (sad §4). Only the
/// current session is read, so another session's photos never appear
/// (spec AC-16); a set is never listed, and a row whose word is cleared does
/// not count (spec AC-15).
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
