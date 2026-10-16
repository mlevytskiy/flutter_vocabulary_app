// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$quizHash() => r'32d632ffe37c6a3dd43a569b052b338c56a5730a';

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

abstract class _$Quiz extends BuildlessAutoDisposeAsyncNotifier<QuizState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<QuizState> build(
    String? collectionId,
    String groupId,
  );
}

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.
///
/// Copied from [Quiz].
@ProviderFor(Quiz)
const quizProvider = QuizFamily();

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.
///
/// Copied from [Quiz].
class QuizFamily extends Family<AsyncValue<QuizState>> {
  /// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
  /// questions. Each final answer records the word's result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  /// Auto-disposed, so leaving the screen forgets the attempt.
  ///
  /// Copied from [Quiz].
  const QuizFamily();

  /// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
  /// questions. Each final answer records the word's result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  /// Auto-disposed, so leaving the screen forgets the attempt.
  ///
  /// Copied from [Quiz].
  QuizProvider call(
    String? collectionId,
    String groupId,
  ) {
    return QuizProvider(
      collectionId,
      groupId,
    );
  }

  @override
  QuizProvider getProviderOverride(
    covariant QuizProvider provider,
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
  String? get name => r'quizProvider';
}

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.
///
/// Copied from [Quiz].
class QuizProvider
    extends AutoDisposeAsyncNotifierProviderImpl<Quiz, QuizState> {
  /// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
  /// questions. Each final answer records the word's result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  /// Auto-disposed, so leaving the screen forgets the attempt.
  ///
  /// Copied from [Quiz].
  QuizProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => Quiz()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: quizProvider,
          name: r'quizProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$quizHash,
          dependencies: QuizFamily._dependencies,
          allTransitiveDependencies: QuizFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  QuizProvider._internal(
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
  FutureOr<QuizState> runNotifierBuild(
    covariant Quiz notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(Quiz Function() create) {
    return ProviderOverride(
      origin: this,
      override: QuizProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<Quiz, QuizState> createElement() {
    return _QuizProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is QuizProvider &&
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
mixin QuizRef on AutoDisposeAsyncNotifierProviderRef<QuizState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _QuizProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<Quiz, QuizState>
    with QuizRef {
  _QuizProviderElement(super.provider);

  @override
  String? get collectionId => (origin as QuizProvider).collectionId;
  @override
  String get groupId => (origin as QuizProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
