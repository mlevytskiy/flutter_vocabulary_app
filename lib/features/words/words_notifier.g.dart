// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'words_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.

@ProviderFor(WordsNotifier)
final wordsProvider = WordsNotifierProvider._();

/// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.
final class WordsNotifierProvider
    extends $AsyncNotifierProvider<WordsNotifier, WordCollection> {
  /// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
  /// its own `_wordPairs` field (controllers, focus nodes and the rest of its
  /// per-row state stay keyed off that field, unchanged) and pushes every
  /// mutation here right after making it.
  WordsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'wordsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wordsNotifierHash();

  @$internal
  @override
  WordsNotifier create() => WordsNotifier();
}

String _$wordsNotifierHash() => r'e76e037de2e78fa2ac76ea95a09f7e0d666b2385';

/// Owns the current [WordCollection]. `WordsScreen` keeps mirroring the words into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it.

abstract class _$WordsNotifier extends $AsyncNotifier<WordCollection> {
  FutureOr<WordCollection> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WordCollection>, WordCollection>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<WordCollection>, WordCollection>,
        AsyncValue<WordCollection>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
