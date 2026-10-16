// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guess_my_word_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guessMyWordHash() => r'0596326c3b28a92ccd92fe94875acb4793169cf0';

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

abstract class _$GuessMyWord
    extends BuildlessAutoDisposeAsyncNotifier<GuessState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<GuessState> build(
    String? collectionId,
    String groupId,
  );
}

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
///
/// Copied from [GuessMyWord].
@ProviderFor(GuessMyWord)
const guessMyWordProvider = GuessMyWordFamily();

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
///
/// Copied from [GuessMyWord].
class GuessMyWordFamily extends Family<AsyncValue<GuessState>> {
  /// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
  /// call for kind `clues`, three masked clues per word (S-51), rounds, scores
  /// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
  ///
  /// Copied from [GuessMyWord].
  const GuessMyWordFamily();

  /// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
  /// call for kind `clues`, three masked clues per word (S-51), rounds, scores
  /// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
  ///
  /// Copied from [GuessMyWord].
  GuessMyWordProvider call(
    String? collectionId,
    String groupId,
  ) {
    return GuessMyWordProvider(
      collectionId,
      groupId,
    );
  }

  @override
  GuessMyWordProvider getProviderOverride(
    covariant GuessMyWordProvider provider,
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
  String? get name => r'guessMyWordProvider';
}

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
///
/// Copied from [GuessMyWord].
class GuessMyWordProvider
    extends AutoDisposeAsyncNotifierProviderImpl<GuessMyWord, GuessState> {
  /// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
  /// call for kind `clues`, three masked clues per word (S-51), rounds, scores
  /// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
  ///
  /// Copied from [GuessMyWord].
  GuessMyWordProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => GuessMyWord()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: guessMyWordProvider,
          name: r'guessMyWordProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$guessMyWordHash,
          dependencies: GuessMyWordFamily._dependencies,
          allTransitiveDependencies:
              GuessMyWordFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  GuessMyWordProvider._internal(
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
  FutureOr<GuessState> runNotifierBuild(
    covariant GuessMyWord notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(GuessMyWord Function() create) {
    return ProviderOverride(
      origin: this,
      override: GuessMyWordProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<GuessMyWord, GuessState>
      createElement() {
    return _GuessMyWordProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuessMyWordProvider &&
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
mixin GuessMyWordRef on AutoDisposeAsyncNotifierProviderRef<GuessState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GuessMyWordProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GuessMyWord, GuessState>
    with GuessMyWordRef {
  _GuessMyWordProviderElement(super.provider);

  @override
  String? get collectionId => (origin as GuessMyWordProvider).collectionId;
  @override
  String get groupId => (origin as GuessMyWordProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
