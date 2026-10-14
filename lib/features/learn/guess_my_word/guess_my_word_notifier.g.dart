// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guess_my_word_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$guessMyWordHash() => r'ee24fa01847cd457672a2f30f092e58043b01bd2';

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
  late final String? sessionId;
  late final String groupId;

  FutureOr<GuessState> build(
    String? sessionId,
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
    String? sessionId,
    String groupId,
  ) {
    return GuessMyWordProvider(
      sessionId,
      groupId,
    );
  }

  @override
  GuessMyWordProvider getProviderOverride(
    covariant GuessMyWordProvider provider,
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
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => GuessMyWord()
            ..sessionId = sessionId
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
          sessionId: sessionId,
          groupId: groupId,
        );

  GuessMyWordProvider._internal(
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
  FutureOr<GuessState> runNotifierBuild(
    covariant GuessMyWord notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(GuessMyWord Function() create) {
    return ProviderOverride(
      origin: this,
      override: GuessMyWordProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<GuessMyWord, GuessState>
      createElement() {
    return _GuessMyWordProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GuessMyWordProvider &&
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
mixin GuessMyWordRef on AutoDisposeAsyncNotifierProviderRef<GuessState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GuessMyWordProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GuessMyWord, GuessState>
    with GuessMyWordRef {
  _GuessMyWordProviderElement(super.provider);

  @override
  String? get sessionId => (origin as GuessMyWordProvider).sessionId;
  @override
  String get groupId => (origin as GuessMyWordProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
