// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_synonyms_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$matchSynonymsHash() => r'defdf386440e7af596e0c70ebc74eda7a84cb0c1';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$MatchSynonyms
    extends BuildlessAutoDisposeAsyncNotifier<MatchRoundsState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<MatchRoundsState> build(
    String? collectionId,
    String groupId,
  );
}

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
///
/// Copied from [MatchSynonyms].
@ProviderFor(MatchSynonyms)
const matchSynonymsProvider = MatchSynonymsFamily();

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
///
/// Copied from [MatchSynonyms].
class MatchSynonymsFamily extends Family<AsyncValue<MatchRoundsState>> {
  /// The match-synonyms exercise of one group (learn-match-synonyms): one
  /// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-21).
  ///
  /// Copied from [MatchSynonyms].
  const MatchSynonymsFamily();

  /// The match-synonyms exercise of one group (learn-match-synonyms): one
  /// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-21).
  ///
  /// Copied from [MatchSynonyms].
  MatchSynonymsProvider call(
    String? collectionId,
    String groupId,
  ) {
    return MatchSynonymsProvider(
      collectionId,
      groupId,
    );
  }

  @override
  MatchSynonymsProvider getProviderOverride(
    covariant MatchSynonymsProvider provider,
  ) {
    return call(
      provider.collectionId,
      provider.groupId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'matchSynonymsProvider';
}

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
///
/// Copied from [MatchSynonyms].
class MatchSynonymsProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MatchSynonyms, MatchRoundsState> {
  /// The match-synonyms exercise of one group (learn-match-synonyms): one
  /// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-21).
  ///
  /// Copied from [MatchSynonyms].
  MatchSynonymsProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => MatchSynonyms()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: matchSynonymsProvider,
          name: r'matchSynonymsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$matchSynonymsHash,
          dependencies: MatchSynonymsFamily._dependencies,
          allTransitiveDependencies:
              MatchSynonymsFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  MatchSynonymsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
    required this.groupId,
  }) : super.internal();

  final String? collectionId;
  final String groupId;

  @override
  FutureOr<MatchRoundsState> runNotifierBuild(
    covariant MatchSynonyms notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(MatchSynonyms Function() create) {
    return ProviderOverride(
      origin: this,
      override: MatchSynonymsProvider._internal(
        () => create()
          ..collectionId = collectionId
          ..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MatchSynonyms, MatchRoundsState>
      createElement() {
    return _MatchSynonymsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MatchSynonymsProvider &&
        other.collectionId == collectionId &&
        other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MatchSynonymsRef
    on AutoDisposeAsyncNotifierProviderRef<MatchRoundsState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _MatchSynonymsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MatchSynonyms,
        MatchRoundsState> with MatchSynonymsRef {
  _MatchSynonymsProviderElement(super.provider);

  @override
  String? get collectionId => (origin as MatchSynonymsProvider).collectionId;
  @override
  String get groupId => (origin as MatchSynonymsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
