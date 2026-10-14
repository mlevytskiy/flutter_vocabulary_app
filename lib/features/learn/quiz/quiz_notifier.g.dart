// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$quizHash() => r'6f8162052e10c2d54e6eb7c75361ea5024c9cdc3';

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
  late final String? sessionId;
  late final String groupId;

  FutureOr<QuizState> build(
    String? sessionId,
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
    String? sessionId,
    String groupId,
  ) {
    return QuizProvider(
      sessionId,
      groupId,
    );
  }

  @override
  QuizProvider getProviderOverride(
    covariant QuizProvider provider,
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
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => Quiz()
            ..sessionId = sessionId
            ..groupId = groupId,
          from: quizProvider,
          name: r'quizProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$quizHash,
          dependencies: QuizFamily._dependencies,
          allTransitiveDependencies: QuizFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  QuizProvider._internal(
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
  FutureOr<QuizState> runNotifierBuild(
    covariant Quiz notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(Quiz Function() create) {
    return ProviderOverride(
      origin: this,
      override: QuizProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<Quiz, QuizState> createElement() {
    return _QuizProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is QuizProvider &&
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
mixin QuizRef on AutoDisposeAsyncNotifierProviderRef<QuizState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _QuizProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<Quiz, QuizState>
    with QuizRef {
  _QuizProviderElement(super.provider);

  @override
  String? get sessionId => (origin as QuizProvider).sessionId;
  @override
  String get groupId => (origin as QuizProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
