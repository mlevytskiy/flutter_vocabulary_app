// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_input_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordInputNotifierHash() => r'59e0c5729e39f4e0550fa4d87e08f72f194b9bb5';

/// Owns the current [Session]. `WordInputScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
///
/// Copied from [WordInputNotifier].
@ProviderFor(WordInputNotifier)
final wordInputNotifierProvider =
    AsyncNotifierProvider<WordInputNotifier, Session>.internal(
  WordInputNotifier.new,
  name: r'wordInputNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordInputNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WordInputNotifier = AsyncNotifier<Session>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
