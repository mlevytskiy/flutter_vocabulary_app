// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_patterns_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sentencePatternsHash() => r'6b6bd20952cd8ee506238874ff40dc9532a01ba8';

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

abstract class _$SentencePatterns
    extends BuildlessAutoDisposeAsyncNotifier<PatternsState> {
  late final String? sessionId;
  late final String groupId;

  FutureOr<PatternsState> build(
    String? sessionId,
    String groupId,
  );
}

/// See also [SentencePatterns].
@ProviderFor(SentencePatterns)
const sentencePatternsProvider = SentencePatternsFamily();

/// See also [SentencePatterns].
class SentencePatternsFamily extends Family<AsyncValue<PatternsState>> {
  /// See also [SentencePatterns].
  const SentencePatternsFamily();

  /// See also [SentencePatterns].
  SentencePatternsProvider call(
    String? sessionId,
    String groupId,
  ) {
    return SentencePatternsProvider(
      sessionId,
      groupId,
    );
  }

  @override
  SentencePatternsProvider getProviderOverride(
    covariant SentencePatternsProvider provider,
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
  String? get name => r'sentencePatternsProvider';
}

/// See also [SentencePatterns].
class SentencePatternsProvider extends AutoDisposeAsyncNotifierProviderImpl<
    SentencePatterns, PatternsState> {
  /// See also [SentencePatterns].
  SentencePatternsProvider(
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => SentencePatterns()
            ..sessionId = sessionId
            ..groupId = groupId,
          from: sentencePatternsProvider,
          name: r'sentencePatternsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sentencePatternsHash,
          dependencies: SentencePatternsFamily._dependencies,
          allTransitiveDependencies:
              SentencePatternsFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  SentencePatternsProvider._internal(
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
  FutureOr<PatternsState> runNotifierBuild(
    covariant SentencePatterns notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(SentencePatterns Function() create) {
    return ProviderOverride(
      origin: this,
      override: SentencePatternsProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<SentencePatterns, PatternsState>
      createElement() {
    return _SentencePatternsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SentencePatternsProvider &&
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
mixin SentencePatternsRef
    on AutoDisposeAsyncNotifierProviderRef<PatternsState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _SentencePatternsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SentencePatterns,
        PatternsState> with SentencePatternsRef {
  _SentencePatternsProviderElement(super.provider);

  @override
  String? get sessionId => (origin as SentencePatternsProvider).sessionId;
  @override
  String get groupId => (origin as SentencePatternsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
