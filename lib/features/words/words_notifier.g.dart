// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'words_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordsNotifierHash() => r'aa8aa2670cfaa2745e8265f40af9fdd74d3ab696';

/// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
///
/// Copied from [WordsNotifier].
@ProviderFor(WordsNotifier)
final wordsNotifierProvider =
    AsyncNotifierProvider<WordsNotifier, WordCollection>.internal(
  WordsNotifier.new,
  name: r'wordsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WordsNotifier = AsyncNotifier<WordCollection>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
