// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_groups_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The groups of one session and the learner's selection among them. A null
/// [collectionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.

@ProviderFor(WordGroupsNotifier)
final wordGroupsProvider = WordGroupsNotifierFamily._();

/// The groups of one session and the learner's selection among them. A null
/// [collectionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
final class WordGroupsNotifierProvider
    extends $NotifierProvider<WordGroupsNotifier, WordGroupsState> {
  /// The groups of one session and the learner's selection among them. A null
  /// [collectionId] is the current session; an id is a History session, which is
  /// read and saved on its own and never becomes current (AC-11). Lives in
  /// `lib/core/story/` so the Words screen and the learn page share it.
  WordGroupsNotifierProvider._(
      {required WordGroupsNotifierFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'wordGroupsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wordGroupsNotifierHash();

  @override
  String toString() {
    return r'wordGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WordGroupsNotifier create() => WordGroupsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordGroupsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordGroupsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WordGroupsNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wordGroupsNotifierHash() =>
    r'4f93ee55e1229058a2b9dee89563263184a2017e';

/// The groups of one session and the learner's selection among them. A null
/// [collectionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.

final class WordGroupsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<WordGroupsNotifier, WordGroupsState,
            WordGroupsState, WordGroupsState, String?> {
  WordGroupsNotifierFamily._()
      : super(
          retry: null,
          name: r'wordGroupsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  /// The groups of one session and the learner's selection among them. A null
  /// [collectionId] is the current session; an id is a History session, which is
  /// read and saved on its own and never becomes current (AC-11). Lives in
  /// `lib/core/story/` so the Words screen and the learn page share it.

  WordGroupsNotifierProvider call(
    String? collectionId,
  ) =>
      WordGroupsNotifierProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'wordGroupsProvider';
}

/// The groups of one session and the learner's selection among them. A null
/// [collectionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.

abstract class _$WordGroupsNotifier extends $Notifier<WordGroupsState> {
  late final _$args = ref.$arg as String?;
  String? get collectionId => _$args;

  WordGroupsState build(
    String? collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WordGroupsState, WordGroupsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<WordGroupsState, WordGroupsState>,
        WordGroupsState,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
