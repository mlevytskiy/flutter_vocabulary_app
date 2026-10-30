// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learn_flow_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
/// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
/// results.
///
/// Built, it reads the collection, picks the card words and asks for the
/// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
/// [chooseMode]) open the cards; then each of the first 3 groups reuses a
/// finished saved story with the same row ids or starts a run in the
/// background, and the mission picture is drawn. Each [rate] writes that
/// word's box at once (ADR-0004). [leave] drops everything not yet saved;
/// started runs go on into Story runs.

@ProviderFor(LearnFlow)
final learnFlowProvider = LearnFlowFamily._();

/// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
/// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
/// results.
///
/// Built, it reads the collection, picks the card words and asks for the
/// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
/// [chooseMode]) open the cards; then each of the first 3 groups reuses a
/// finished saved story with the same row ids or starts a run in the
/// background, and the mission picture is drawn. Each [rate] writes that
/// word's box at once (ADR-0004). [leave] drops everything not yet saved;
/// started runs go on into Story runs.
final class LearnFlowProvider
    extends $NotifierProvider<LearnFlow, LearnFlowState> {
  /// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
  /// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
  /// results.
  ///
  /// Built, it reads the collection, picks the card words and asks for the
  /// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
  /// [chooseMode]) open the cards; then each of the first 3 groups reuses a
  /// finished saved story with the same row ids or starts a run in the
  /// background, and the mission picture is drawn. Each [rate] writes that
  /// word's box at once (ADR-0004). [leave] drops everything not yet saved;
  /// started runs go on into Story runs.
  LearnFlowProvider._(
      {required LearnFlowFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'learnFlowProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnFlowHash();

  @override
  String toString() {
    return r'learnFlowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LearnFlow create() => LearnFlow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearnFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearnFlowState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearnFlowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learnFlowHash() => r'04f4f50e4b47b5c26c4bcd8848d2462ccfbd1954';

/// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
/// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
/// results.
///
/// Built, it reads the collection, picks the card words and asks for the
/// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
/// [chooseMode]) open the cards; then each of the first 3 groups reuses a
/// finished saved story with the same row ids or starts a run in the
/// background, and the mission picture is drawn. Each [rate] writes that
/// word's box at once (ADR-0004). [leave] drops everything not yet saved;
/// started runs go on into Story runs.

final class LearnFlowFamily extends $Family
    with
        $ClassFamilyOverride<LearnFlow, LearnFlowState, LearnFlowState,
            LearnFlowState, String> {
  LearnFlowFamily._()
      : super(
          retry: null,
          name: r'learnFlowProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
  /// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
  /// results.
  ///
  /// Built, it reads the collection, picks the card words and asks for the
  /// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
  /// [chooseMode]) open the cards; then each of the first 3 groups reuses a
  /// finished saved story with the same row ids or starts a run in the
  /// background, and the mission picture is drawn. Each [rate] writes that
  /// word's box at once (ADR-0004). [leave] drops everything not yet saved;
  /// started runs go on into Story runs.

  LearnFlowProvider call(
    String collectionId,
  ) =>
      LearnFlowProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'learnFlowProvider';
}

/// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
/// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
/// results.
///
/// Built, it reads the collection, picks the card words and asks for the
/// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
/// [chooseMode]) open the cards; then each of the first 3 groups reuses a
/// finished saved story with the same row ids or starts a run in the
/// background, and the mission picture is drawn. Each [rate] writes that
/// word's box at once (ADR-0004). [leave] drops everything not yet saved;
/// started runs go on into Story runs.

abstract class _$LearnFlow extends $Notifier<LearnFlowState> {
  late final _$args = ref.$arg as String;
  String get collectionId => _$args;

  LearnFlowState build(
    String collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearnFlowState, LearnFlowState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LearnFlowState, LearnFlowState>,
        LearnFlowState,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

/// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
/// the flow of [collectionId] reaches the dialog.

@ProviderFor(learnFlowDialogSetup)
final learnFlowDialogSetupProvider = LearnFlowDialogSetupFamily._();

/// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
/// the flow of [collectionId] reaches the dialog.

final class LearnFlowDialogSetupProvider extends $FunctionalProvider<
    LearnDialogSetup?,
    LearnDialogSetup?,
    LearnDialogSetup?> with $Provider<LearnDialogSetup?> {
  /// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
  /// the flow of [collectionId] reaches the dialog.
  LearnFlowDialogSetupProvider._(
      {required LearnFlowDialogSetupFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'learnFlowDialogSetupProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnFlowDialogSetupHash();

  @override
  String toString() {
    return r'learnFlowDialogSetupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<LearnDialogSetup?> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LearnDialogSetup? create(Ref ref) {
    final argument = this.argument as String;
    return learnFlowDialogSetup(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearnDialogSetup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearnDialogSetup?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearnFlowDialogSetupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learnFlowDialogSetupHash() =>
    r'8311b3f43fb2491cca3ae8c291247802e9d13086';

/// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
/// the flow of [collectionId] reaches the dialog.

final class LearnFlowDialogSetupFamily extends $Family
    with $FunctionalFamilyOverride<LearnDialogSetup?, String> {
  LearnFlowDialogSetupFamily._()
      : super(
          retry: null,
          name: r'learnFlowDialogSetupProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
  /// the flow of [collectionId] reaches the dialog.

  LearnFlowDialogSetupProvider call(
    String collectionId,
  ) =>
      LearnFlowDialogSetupProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'learnFlowDialogSetupProvider';
}
