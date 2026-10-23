// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'own_sentences_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.

@ProviderFor(OwnSentences)
final ownSentencesProvider = OwnSentencesFamily._();

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
final class OwnSentencesProvider
    extends $AsyncNotifierProvider<OwnSentences, OwnState> {
  /// The own-sentences exam of one group (learn-own-sentences). No Worker data:
  /// only the group's words are read. Each final word records its result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  OwnSentencesProvider._(
      {required OwnSentencesFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'ownSentencesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ownSentencesHash();

  @override
  String toString() {
    return r'ownSentencesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  OwnSentences create() => OwnSentences();

  @override
  bool operator ==(Object other) {
    return other is OwnSentencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ownSentencesHash() => r'7a706f2d13886445466d66ecf4b3037917a1a5e8';

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.

final class OwnSentencesFamily extends $Family
    with
        $ClassFamilyOverride<
            OwnSentences,
            AsyncValue<OwnState>,
            OwnState,
            FutureOr<OwnState>,
            (
              String?,
              String,
            )> {
  OwnSentencesFamily._()
      : super(
          retry: null,
          name: r'ownSentencesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The own-sentences exam of one group (learn-own-sentences). No Worker data:
  /// only the group's words are read. Each final word records its result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.

  OwnSentencesProvider call(
    String? collectionId,
    String groupId,
  ) =>
      OwnSentencesProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'ownSentencesProvider';
}

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.

abstract class _$OwnSentences extends $AsyncNotifier<OwnState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<OwnState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<OwnState>, OwnState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<OwnState>, OwnState>,
        AsyncValue<OwnState>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args.$1,
              _$args.$2,
            ));
  }
}
