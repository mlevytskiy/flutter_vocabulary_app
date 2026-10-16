// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translate_sentences_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$translateSentencesHash() =>
    r'00a799b85bbe38609ed74ab7dbaa7a9bfda652ba';

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

abstract class _$TranslateSentences
    extends BuildlessAutoDisposeAsyncNotifier<TranslateState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<TranslateState> build(
    String? collectionId,
    String groupId,
  );
}

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.
///
/// Copied from [TranslateSentences].
@ProviderFor(TranslateSentences)
const translateSentencesProvider = TranslateSentencesFamily();

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.
///
/// Copied from [TranslateSentences].
class TranslateSentencesFamily extends Family<AsyncValue<TranslateState>> {
  /// The translation exam of one group (learn-translate-sentences). Each final
  /// word records its result through [examResultSinkProvider] at once (S-55);
  /// nothing else is saved. Auto-disposed, so leaving forgets the exam.
  ///
  /// Copied from [TranslateSentences].
  const TranslateSentencesFamily();

  /// The translation exam of one group (learn-translate-sentences). Each final
  /// word records its result through [examResultSinkProvider] at once (S-55);
  /// nothing else is saved. Auto-disposed, so leaving forgets the exam.
  ///
  /// Copied from [TranslateSentences].
  TranslateSentencesProvider call(
    String? collectionId,
    String groupId,
  ) {
    return TranslateSentencesProvider(
      collectionId,
      groupId,
    );
  }

  @override
  TranslateSentencesProvider getProviderOverride(
    covariant TranslateSentencesProvider provider,
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
  String? get name => r'translateSentencesProvider';
}

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.
///
/// Copied from [TranslateSentences].
class TranslateSentencesProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TranslateSentences, TranslateState> {
  /// The translation exam of one group (learn-translate-sentences). Each final
  /// word records its result through [examResultSinkProvider] at once (S-55);
  /// nothing else is saved. Auto-disposed, so leaving forgets the exam.
  ///
  /// Copied from [TranslateSentences].
  TranslateSentencesProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => TranslateSentences()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: translateSentencesProvider,
          name: r'translateSentencesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$translateSentencesHash,
          dependencies: TranslateSentencesFamily._dependencies,
          allTransitiveDependencies:
              TranslateSentencesFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  TranslateSentencesProvider._internal(
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
  FutureOr<TranslateState> runNotifierBuild(
    covariant TranslateSentences notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(TranslateSentences Function() create) {
    return ProviderOverride(
      origin: this,
      override: TranslateSentencesProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TranslateSentences, TranslateState>
      createElement() {
    return _TranslateSentencesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TranslateSentencesProvider &&
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
mixin TranslateSentencesRef
    on AutoDisposeAsyncNotifierProviderRef<TranslateState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _TranslateSentencesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TranslateSentences,
        TranslateState> with TranslateSentencesRef {
  _TranslateSentencesProviderElement(super.provider);

  @override
  String? get collectionId =>
      (origin as TranslateSentencesProvider).collectionId;
  @override
  String get groupId => (origin as TranslateSentencesProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
