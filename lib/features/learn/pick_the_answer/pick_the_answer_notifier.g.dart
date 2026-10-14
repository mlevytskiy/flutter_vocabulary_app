// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pick_the_answer_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pickTheAnswerHash() => r'4af27044683fd725cdaea53545db9039794d6f70';

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

abstract class _$PickTheAnswer
    extends BuildlessAutoDisposeAsyncNotifier<PickState> {
  late final String? sessionId;
  late final String groupId;

  FutureOr<PickState> build(
    String? sessionId,
    String groupId,
  );
}

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.
///
/// Copied from [PickTheAnswer].
@ProviderFor(PickTheAnswer)
const pickTheAnswerProvider = PickTheAnswerFamily();

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.
///
/// Copied from [PickTheAnswer].
class PickTheAnswerFamily extends Family<AsyncValue<PickState>> {
  /// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
  /// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
  /// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
  /// the round.
  ///
  /// Copied from [PickTheAnswer].
  const PickTheAnswerFamily();

  /// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
  /// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
  /// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
  /// the round.
  ///
  /// Copied from [PickTheAnswer].
  PickTheAnswerProvider call(
    String? sessionId,
    String groupId,
  ) {
    return PickTheAnswerProvider(
      sessionId,
      groupId,
    );
  }

  @override
  PickTheAnswerProvider getProviderOverride(
    covariant PickTheAnswerProvider provider,
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
  String? get name => r'pickTheAnswerProvider';
}

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.
///
/// Copied from [PickTheAnswer].
class PickTheAnswerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<PickTheAnswer, PickState> {
  /// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
  /// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
  /// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
  /// the round.
  ///
  /// Copied from [PickTheAnswer].
  PickTheAnswerProvider(
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => PickTheAnswer()
            ..sessionId = sessionId
            ..groupId = groupId,
          from: pickTheAnswerProvider,
          name: r'pickTheAnswerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$pickTheAnswerHash,
          dependencies: PickTheAnswerFamily._dependencies,
          allTransitiveDependencies:
              PickTheAnswerFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  PickTheAnswerProvider._internal(
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
  FutureOr<PickState> runNotifierBuild(
    covariant PickTheAnswer notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(PickTheAnswer Function() create) {
    return ProviderOverride(
      origin: this,
      override: PickTheAnswerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<PickTheAnswer, PickState>
      createElement() {
    return _PickTheAnswerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PickTheAnswerProvider &&
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
mixin PickTheAnswerRef on AutoDisposeAsyncNotifierProviderRef<PickState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _PickTheAnswerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PickTheAnswer, PickState>
    with PickTheAnswerRef {
  _PickTheAnswerProviderElement(super.provider);

  @override
  String? get sessionId => (origin as PickTheAnswerProvider).sessionId;
  @override
  String get groupId => (origin as PickTheAnswerProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
