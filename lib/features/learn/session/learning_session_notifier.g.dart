// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.

@ProviderFor(LearningSession)
final learningSessionProvider = LearningSessionFamily._();

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.
final class LearningSessionProvider
    extends $NotifierProvider<LearningSession, LearningSessionState> {
  /// One learning session of a collection (learn-redesign ADR-0004; AC-02,
  /// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
  /// collection, as in `exerciseWords`.
  ///
  /// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
  /// exercise types per step, builds step 1's pages and shows the first one;
  /// steps 2 and 3 load in the background and are awaited when the first word
  /// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
  /// unused page of that step holding the word, rotating exercise types. AI
  /// data is fetched in batches of at most [batchSize] words. Leaving a
  /// session changes no box (AC-16); only finishing writes them, once.
  LearningSessionProvider._(
      {required LearningSessionFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'learningSessionProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learningSessionHash();

  @override
  String toString() {
    return r'learningSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LearningSession create() => LearningSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningSessionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearningSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learningSessionHash() => r'f01243df74503a8fc95e7aa6193f1e1e3f1928e7';

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.

final class LearningSessionFamily extends $Family
    with
        $ClassFamilyOverride<LearningSession, LearningSessionState,
            LearningSessionState, LearningSessionState, String?> {
  LearningSessionFamily._()
      : super(
          retry: null,
          name: r'learningSessionProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// One learning session of a collection (learn-redesign ADR-0004; AC-02,
  /// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
  /// collection, as in `exerciseWords`.
  ///
  /// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
  /// exercise types per step, builds step 1's pages and shows the first one;
  /// steps 2 and 3 load in the background and are awaited when the first word
  /// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
  /// unused page of that step holding the word, rotating exercise types. AI
  /// data is fetched in batches of at most [batchSize] words. Leaving a
  /// session changes no box (AC-16); only finishing writes them, once.

  LearningSessionProvider call(
    String? collectionId,
  ) =>
      LearningSessionProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'learningSessionProvider';
}

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.

abstract class _$LearningSession extends $Notifier<LearningSessionState> {
  late final _$args = ref.$arg as String?;
  String? get collectionId => _$args;

  LearningSessionState build(
    String? collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearningSessionState, LearningSessionState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LearningSessionState, LearningSessionState>,
        LearningSessionState,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
