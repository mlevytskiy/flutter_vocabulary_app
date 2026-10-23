// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guess_my_word_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).

@ProviderFor(GuessMyWord)
final guessMyWordProvider = GuessMyWordFamily._();

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
final class GuessMyWordProvider
    extends $AsyncNotifierProvider<GuessMyWord, GuessState> {
  /// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
  /// call for kind `clues`, three masked clues per word (S-51), rounds, scores
  /// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
  GuessMyWordProvider._(
      {required GuessMyWordFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'guessMyWordProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$guessMyWordHash();

  @override
  String toString() {
    return r'guessMyWordProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  GuessMyWord create() => GuessMyWord();

  @override
  bool operator ==(Object other) {
    return other is GuessMyWordProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guessMyWordHash() => r'7a91971ef81174c4b3313dedbf9b93c54bcf03f8';

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).

final class GuessMyWordFamily extends $Family
    with
        $ClassFamilyOverride<
            GuessMyWord,
            AsyncValue<GuessState>,
            GuessState,
            FutureOr<GuessState>,
            (
              String?,
              String,
            )> {
  GuessMyWordFamily._()
      : super(
          retry: null,
          name: r'guessMyWordProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
  /// call for kind `clues`, three masked clues per word (S-51), rounds, scores
  /// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).

  GuessMyWordProvider call(
    String? collectionId,
    String groupId,
  ) =>
      GuessMyWordProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'guessMyWordProvider';
}

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).

abstract class _$GuessMyWord extends $AsyncNotifier<GuessState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<GuessState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<GuessState>, GuessState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<GuessState>, GuessState>,
        AsyncValue<GuessState>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args.$1,
              _$args.$2,
            ));
  }
}
