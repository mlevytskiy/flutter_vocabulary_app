// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_synonyms_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).

@ProviderFor(MatchSynonyms)
final matchSynonymsProvider = MatchSynonymsFamily._();

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
final class MatchSynonymsProvider
    extends $AsyncNotifierProvider<MatchSynonyms, MatchRoundsState> {
  /// The match-synonyms exercise of one group (learn-match-synonyms): one
  /// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-21).
  MatchSynonymsProvider._(
      {required MatchSynonymsFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'matchSynonymsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$matchSynonymsHash();

  @override
  String toString() {
    return r'matchSynonymsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  MatchSynonyms create() => MatchSynonyms();

  @override
  bool operator ==(Object other) {
    return other is MatchSynonymsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchSynonymsHash() => r'328bfdc3073591f58a7b5026322676caeddf91ce';

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).

final class MatchSynonymsFamily extends $Family
    with
        $ClassFamilyOverride<
            MatchSynonyms,
            AsyncValue<MatchRoundsState>,
            MatchRoundsState,
            FutureOr<MatchRoundsState>,
            (
              String?,
              String,
            )> {
  MatchSynonymsFamily._()
      : super(
          retry: null,
          name: r'matchSynonymsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The match-synonyms exercise of one group (learn-match-synonyms): one
  /// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-21).

  MatchSynonymsProvider call(
    String? collectionId,
    String groupId,
  ) =>
      MatchSynonymsProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'matchSynonymsProvider';
}

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).

abstract class _$MatchSynonyms extends $AsyncNotifier<MatchRoundsState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<MatchRoundsState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MatchRoundsState>, MatchRoundsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<MatchRoundsState>, MatchRoundsState>,
        AsyncValue<MatchRoundsState>,
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
