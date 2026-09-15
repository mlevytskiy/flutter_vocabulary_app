// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_input_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordInputNotifierHash() => r'3e16f3df8130cdc7453413673567c15c5ece96bf';

/// Owns the persisted word list. `WordInputScreen` keeps mirroring this into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it, so this notifier is always a beat
/// behind the screen, never the other way around -- except once, on first
/// load, when the screen pulls the persisted list in to restore it.
///
/// Copied from [WordInputNotifier].
@ProviderFor(WordInputNotifier)
final wordInputNotifierProvider =
    AsyncNotifierProvider<WordInputNotifier, List<WordPair>>.internal(
  WordInputNotifier.new,
  name: r'wordInputNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordInputNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WordInputNotifier = AsyncNotifier<List<WordPair>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
