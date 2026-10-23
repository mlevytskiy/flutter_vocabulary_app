// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_definitions_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).

@ProviderFor(MatchDefinitions)
final matchDefinitionsProvider = MatchDefinitionsFamily._();

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).
final class MatchDefinitionsProvider
    extends $AsyncNotifierProvider<MatchDefinitions, MatchRoundsState> {
  /// The match-word-and-definition exercise of one group
  /// (learn-match-definitions): a word's stored definition line first, else one
  /// Worker call for the words without one (S-42); nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-22).
  MatchDefinitionsProvider._(
      {required MatchDefinitionsFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'matchDefinitionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$matchDefinitionsHash();

  @override
  String toString() {
    return r'matchDefinitionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  MatchDefinitions create() => MatchDefinitions();

  @override
  bool operator ==(Object other) {
    return other is MatchDefinitionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchDefinitionsHash() => r'c6a37e656a226843f9a57e941d4a664f0c63ecf0';

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).

final class MatchDefinitionsFamily extends $Family
    with
        $ClassFamilyOverride<
            MatchDefinitions,
            AsyncValue<MatchRoundsState>,
            MatchRoundsState,
            FutureOr<MatchRoundsState>,
            (
              String?,
              String,
            )> {
  MatchDefinitionsFamily._()
      : super(
          retry: null,
          name: r'matchDefinitionsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The match-word-and-definition exercise of one group
  /// (learn-match-definitions): a word's stored definition line first, else one
  /// Worker call for the words without one (S-42); nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-22).

  MatchDefinitionsProvider call(
    String? collectionId,
    String groupId,
  ) =>
      MatchDefinitionsProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'matchDefinitionsProvider';
}

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).

abstract class _$MatchDefinitions extends $AsyncNotifier<MatchRoundsState> {
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
