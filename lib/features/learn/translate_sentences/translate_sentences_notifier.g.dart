// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translate_sentences_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.

@ProviderFor(TranslateSentences)
final translateSentencesProvider = TranslateSentencesFamily._();

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.
final class TranslateSentencesProvider
    extends $AsyncNotifierProvider<TranslateSentences, TranslateState> {
  /// The translation exam of one group (learn-translate-sentences). Each final
  /// word records its result through [examResultSinkProvider] at once (S-55);
  /// nothing else is saved. Auto-disposed, so leaving forgets the exam.
  TranslateSentencesProvider._(
      {required TranslateSentencesFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'translateSentencesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$translateSentencesHash();

  @override
  String toString() {
    return r'translateSentencesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  TranslateSentences create() => TranslateSentences();

  @override
  bool operator ==(Object other) {
    return other is TranslateSentencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$translateSentencesHash() =>
    r'ca6644c4fe69899f5cd1325fa6f5d3993f53ed9f';

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.

final class TranslateSentencesFamily extends $Family
    with
        $ClassFamilyOverride<
            TranslateSentences,
            AsyncValue<TranslateState>,
            TranslateState,
            FutureOr<TranslateState>,
            (
              String?,
              String,
            )> {
  TranslateSentencesFamily._()
      : super(
          retry: null,
          name: r'translateSentencesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The translation exam of one group (learn-translate-sentences). Each final
  /// word records its result through [examResultSinkProvider] at once (S-55);
  /// nothing else is saved. Auto-disposed, so leaving forgets the exam.

  TranslateSentencesProvider call(
    String? collectionId,
    String groupId,
  ) =>
      TranslateSentencesProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'translateSentencesProvider';
}

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.

abstract class _$TranslateSentences extends $AsyncNotifier<TranslateState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<TranslateState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TranslateState>, TranslateState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<TranslateState>, TranslateState>,
        AsyncValue<TranslateState>,
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
