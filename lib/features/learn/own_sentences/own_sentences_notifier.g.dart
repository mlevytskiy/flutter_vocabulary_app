// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'own_sentences_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ownSentencesHash() => r'71d77cbfd36be489b69b1804eb466b70a227007b';

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

abstract class _$OwnSentences
    extends BuildlessAutoDisposeAsyncNotifier<OwnState> {
  late final String? sessionId;
  late final String groupId;

  FutureOr<OwnState> build(
    String? sessionId,
    String groupId,
  );
}

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
///
/// Copied from [OwnSentences].
@ProviderFor(OwnSentences)
const ownSentencesProvider = OwnSentencesFamily();

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
///
/// Copied from [OwnSentences].
class OwnSentencesFamily extends Family<AsyncValue<OwnState>> {
  /// The own-sentences exam of one group (learn-own-sentences). No Worker data:
  /// only the group's words are read. Each final word records its result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  ///
  /// Copied from [OwnSentences].
  const OwnSentencesFamily();

  /// The own-sentences exam of one group (learn-own-sentences). No Worker data:
  /// only the group's words are read. Each final word records its result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  ///
  /// Copied from [OwnSentences].
  OwnSentencesProvider call(
    String? sessionId,
    String groupId,
  ) {
    return OwnSentencesProvider(
      sessionId,
      groupId,
    );
  }

  @override
  OwnSentencesProvider getProviderOverride(
    covariant OwnSentencesProvider provider,
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
  String? get name => r'ownSentencesProvider';
}

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
///
/// Copied from [OwnSentences].
class OwnSentencesProvider
    extends AutoDisposeAsyncNotifierProviderImpl<OwnSentences, OwnState> {
  /// The own-sentences exam of one group (learn-own-sentences). No Worker data:
  /// only the group's words are read. Each final word records its result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  ///
  /// Copied from [OwnSentences].
  OwnSentencesProvider(
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => OwnSentences()
            ..sessionId = sessionId
            ..groupId = groupId,
          from: ownSentencesProvider,
          name: r'ownSentencesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$ownSentencesHash,
          dependencies: OwnSentencesFamily._dependencies,
          allTransitiveDependencies:
              OwnSentencesFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  OwnSentencesProvider._internal(
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
  FutureOr<OwnState> runNotifierBuild(
    covariant OwnSentences notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(OwnSentences Function() create) {
    return ProviderOverride(
      origin: this,
      override: OwnSentencesProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<OwnSentences, OwnState>
      createElement() {
    return _OwnSentencesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OwnSentencesProvider &&
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
mixin OwnSentencesRef on AutoDisposeAsyncNotifierProviderRef<OwnState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _OwnSentencesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<OwnSentences, OwnState>
    with OwnSentencesRef {
  _OwnSentencesProviderElement(super.provider);

  @override
  String? get sessionId => (origin as OwnSentencesProvider).sessionId;
  @override
  String get groupId => (origin as OwnSentencesProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
