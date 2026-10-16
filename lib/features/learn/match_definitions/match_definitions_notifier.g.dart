// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_definitions_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$matchDefinitionsHash() => r'15205c77f488dc262f46025179214ee4707da979';

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

abstract class _$MatchDefinitions
    extends BuildlessAutoDisposeAsyncNotifier<MatchRoundsState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<MatchRoundsState> build(
    String? collectionId,
    String groupId,
  );
}

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).
///
/// Copied from [MatchDefinitions].
@ProviderFor(MatchDefinitions)
const matchDefinitionsProvider = MatchDefinitionsFamily();

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).
///
/// Copied from [MatchDefinitions].
class MatchDefinitionsFamily extends Family<AsyncValue<MatchRoundsState>> {
  /// The match-word-and-definition exercise of one group
  /// (learn-match-definitions): a word's stored definition line first, else one
  /// Worker call for the words without one (S-42); nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-22).
  ///
  /// Copied from [MatchDefinitions].
  const MatchDefinitionsFamily();

  /// The match-word-and-definition exercise of one group
  /// (learn-match-definitions): a word's stored definition line first, else one
  /// Worker call for the words without one (S-42); nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-22).
  ///
  /// Copied from [MatchDefinitions].
  MatchDefinitionsProvider call(
    String? collectionId,
    String groupId,
  ) {
    return MatchDefinitionsProvider(
      collectionId,
      groupId,
    );
  }

  @override
  MatchDefinitionsProvider getProviderOverride(
    covariant MatchDefinitionsProvider provider,
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
  String? get name => r'matchDefinitionsProvider';
}

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).
///
/// Copied from [MatchDefinitions].
class MatchDefinitionsProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MatchDefinitions, MatchRoundsState> {
  /// The match-word-and-definition exercise of one group
  /// (learn-match-definitions): a word's stored definition line first, else one
  /// Worker call for the words without one (S-42); nothing saved (D-04).
  /// Auto-disposed, so leaving the screen forgets the round (AC-22).
  ///
  /// Copied from [MatchDefinitions].
  MatchDefinitionsProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => MatchDefinitions()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: matchDefinitionsProvider,
          name: r'matchDefinitionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$matchDefinitionsHash,
          dependencies: MatchDefinitionsFamily._dependencies,
          allTransitiveDependencies:
              MatchDefinitionsFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  MatchDefinitionsProvider._internal(
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
    covariant MatchDefinitions notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(MatchDefinitions Function() create) {
    return ProviderOverride(
      origin: this,
      override: MatchDefinitionsProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<MatchDefinitions, MatchRoundsState>
      createElement() {
    return _MatchDefinitionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MatchDefinitionsProvider &&
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
mixin MatchDefinitionsRef
    on AutoDisposeAsyncNotifierProviderRef<MatchRoundsState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _MatchDefinitionsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MatchDefinitions,
        MatchRoundsState> with MatchDefinitionsRef {
  _MatchDefinitionsProviderElement(super.provider);

  @override
  String? get collectionId => (origin as MatchDefinitionsProvider).collectionId;
  @override
  String get groupId => (origin as MatchDefinitionsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
