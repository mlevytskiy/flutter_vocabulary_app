// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_definitions_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$matchDefinitionsHash() => r'54b3e8ae0f742c971657c1dcd407461c1a73e1ca';

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
  late final String? sessionId;
  late final String groupId;

  FutureOr<MatchRoundsState> build(
    String? sessionId,
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
    String? sessionId,
    String groupId,
  ) {
    return MatchDefinitionsProvider(
      sessionId,
      groupId,
    );
  }

  @override
  MatchDefinitionsProvider getProviderOverride(
    covariant MatchDefinitionsProvider provider,
  ) {
    return call(
      provider.sessionId,
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
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => MatchDefinitions()
            ..sessionId = sessionId
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
          sessionId: sessionId,
          groupId: groupId,
        );

  MatchDefinitionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
    required this.groupId,
  }) : super.internal();

  final String? sessionId;
  final String groupId;

  @override
  FutureOr<MatchRoundsState> runNotifierBuild(
    covariant MatchDefinitions notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(MatchDefinitions Function() create) {
    return ProviderOverride(
      origin: this,
      override: MatchDefinitionsProvider._internal(
        () => create()
          ..sessionId = sessionId
          ..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
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
        other.sessionId == sessionId &&
        other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MatchDefinitionsRef
    on AutoDisposeAsyncNotifierProviderRef<MatchRoundsState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _MatchDefinitionsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MatchDefinitions,
        MatchRoundsState> with MatchDefinitionsRef {
  _MatchDefinitionsProviderElement(super.provider);

  @override
  String? get sessionId => (origin as MatchDefinitionsProvider).sessionId;
  @override
  String get groupId => (origin as MatchDefinitionsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
