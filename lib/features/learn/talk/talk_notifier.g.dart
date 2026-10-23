// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'talk_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$talkHash() => r'24d2bb9353e6866056fb1185f0cc008955408b3d';

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

abstract class _$Talk extends BuildlessAutoDisposeNotifier<TalkState> {
  late final String? collectionId;

  TalkState build(
    String? collectionId,
  );
}

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]), sets the scene from stored
/// text ([scenePick]), ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).
///
/// Copied from [Talk].
@ProviderFor(Talk)
const talkProvider = TalkFamily();

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]), sets the scene from stored
/// text ([scenePick]), ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).
///
/// Copied from [Talk].
class TalkFamily extends Family<TalkState> {
  /// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
  /// [collectionId] is the current collection. The talk takes the words a
  /// learning session would ([pickSessionWords]), sets the scene from stored
  /// text ([scenePick]), ticks words from the learner's own replies only
  /// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
  /// Leaving without [finish] writes nothing (AC-22).
  ///
  /// Copied from [Talk].
  const TalkFamily();

  /// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
  /// [collectionId] is the current collection. The talk takes the words a
  /// learning session would ([pickSessionWords]), sets the scene from stored
  /// text ([scenePick]), ticks words from the learner's own replies only
  /// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
  /// Leaving without [finish] writes nothing (AC-22).
  ///
  /// Copied from [Talk].
  TalkProvider call(
    String? collectionId,
  ) {
    return TalkProvider(
      collectionId,
    );
  }

  @override
  TalkProvider getProviderOverride(
    covariant TalkProvider provider,
  ) {
    return call(
      provider.collectionId,
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
  String? get name => r'talkProvider';
}

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]), sets the scene from stored
/// text ([scenePick]), ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).
///
/// Copied from [Talk].
class TalkProvider extends AutoDisposeNotifierProviderImpl<Talk, TalkState> {
  /// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
  /// [collectionId] is the current collection. The talk takes the words a
  /// learning session would ([pickSessionWords]), sets the scene from stored
  /// text ([scenePick]), ticks words from the learner's own replies only
  /// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
  /// Leaving without [finish] writes nothing (AC-22).
  ///
  /// Copied from [Talk].
  TalkProvider(
    String? collectionId,
  ) : this._internal(
          () => Talk()..collectionId = collectionId,
          from: talkProvider,
          name: r'talkProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$talkHash,
          dependencies: TalkFamily._dependencies,
          allTransitiveDependencies: TalkFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  TalkProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
  }) : super.internal();

  final String? collectionId;

  @override
  TalkState runNotifierBuild(
    covariant Talk notifier,
  ) {
    return notifier.build(
      collectionId,
    );
  }

  @override
  Override overrideWith(Talk Function() create) {
    return ProviderOverride(
      origin: this,
      override: TalkProvider._internal(
        () => create()..collectionId = collectionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<Talk, TalkState> createElement() {
    return _TalkProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TalkProvider && other.collectionId == collectionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TalkRef on AutoDisposeNotifierProviderRef<TalkState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;
}

class _TalkProviderElement
    extends AutoDisposeNotifierProviderElement<Talk, TalkState> with TalkRef {
  _TalkProviderElement(super.provider);

  @override
  String? get collectionId => (origin as TalkProvider).collectionId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
