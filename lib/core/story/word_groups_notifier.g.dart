// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_groups_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordGroupsNotifierHash() =>
    r'55d5b6f32b4ac84baaf860ae0b8e26f0750aa95c';

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

abstract class _$WordGroupsNotifier extends BuildlessNotifier<WordGroupsState> {
  late final String? sessionId;

  WordGroupsState build(
    String? sessionId,
  );
}

/// The groups of one session and the learner's selection among them. A null
/// [sessionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
///
/// Copied from [WordGroupsNotifier].
@ProviderFor(WordGroupsNotifier)
const wordGroupsNotifierProvider = WordGroupsNotifierFamily();

/// The groups of one session and the learner's selection among them. A null
/// [sessionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
///
/// Copied from [WordGroupsNotifier].
class WordGroupsNotifierFamily extends Family<WordGroupsState> {
  /// The groups of one session and the learner's selection among them. A null
  /// [sessionId] is the current session; an id is a History session, which is
  /// read and saved on its own and never becomes current (AC-11). Lives in
  /// `lib/core/story/` so the Words screen and the learn page share it.
  ///
  /// Copied from [WordGroupsNotifier].
  const WordGroupsNotifierFamily();

  /// The groups of one session and the learner's selection among them. A null
  /// [sessionId] is the current session; an id is a History session, which is
  /// read and saved on its own and never becomes current (AC-11). Lives in
  /// `lib/core/story/` so the Words screen and the learn page share it.
  ///
  /// Copied from [WordGroupsNotifier].
  WordGroupsNotifierProvider call(
    String? sessionId,
  ) {
    return WordGroupsNotifierProvider(
      sessionId,
    );
  }

  @override
  WordGroupsNotifierProvider getProviderOverride(
    covariant WordGroupsNotifierProvider provider,
  ) {
    return call(
      provider.sessionId,
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
  String? get name => r'wordGroupsNotifierProvider';
}

/// The groups of one session and the learner's selection among them. A null
/// [sessionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
///
/// Copied from [WordGroupsNotifier].
class WordGroupsNotifierProvider
    extends NotifierProviderImpl<WordGroupsNotifier, WordGroupsState> {
  /// The groups of one session and the learner's selection among them. A null
  /// [sessionId] is the current session; an id is a History session, which is
  /// read and saved on its own and never becomes current (AC-11). Lives in
  /// `lib/core/story/` so the Words screen and the learn page share it.
  ///
  /// Copied from [WordGroupsNotifier].
  WordGroupsNotifierProvider(
    String? sessionId,
  ) : this._internal(
          () => WordGroupsNotifier()..sessionId = sessionId,
          from: wordGroupsNotifierProvider,
          name: r'wordGroupsNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$wordGroupsNotifierHash,
          dependencies: WordGroupsNotifierFamily._dependencies,
          allTransitiveDependencies:
              WordGroupsNotifierFamily._allTransitiveDependencies,
          sessionId: sessionId,
        );

  WordGroupsNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String? sessionId;

  @override
  WordGroupsState runNotifierBuild(
    covariant WordGroupsNotifier notifier,
  ) {
    return notifier.build(
      sessionId,
    );
  }

  @override
  Override overrideWith(WordGroupsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: WordGroupsNotifierProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  NotifierProviderElement<WordGroupsNotifier, WordGroupsState> createElement() {
    return _WordGroupsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WordGroupsNotifierProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WordGroupsNotifierRef on NotifierProviderRef<WordGroupsState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;
}

class _WordGroupsNotifierProviderElement
    extends NotifierProviderElement<WordGroupsNotifier, WordGroupsState>
    with WordGroupsNotifierRef {
  _WordGroupsNotifierProviderElement(super.provider);

  @override
  String? get sessionId => (origin as WordGroupsNotifierProvider).sessionId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
