// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_input_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordInputNotifierHash() => r'4bac49f22b011bc2a1a5e78919b372f9764f6bab';

/// Owns the current [WordCollection]. `WordInputScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
///
/// Copied from [WordInputNotifier].
@ProviderFor(WordInputNotifier)
final wordInputNotifierProvider =
    AsyncNotifierProvider<WordInputNotifier, WordCollection>.internal(
  WordInputNotifier.new,
  name: r'wordInputNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordInputNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WordInputNotifier = AsyncNotifier<WordCollection>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
