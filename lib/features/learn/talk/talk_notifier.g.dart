// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'talk_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]) and sends the collection's
/// name and description as the topic ([scenePick]); the Worker plans a
/// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
/// never the mnemonic story), the talk keeps only those, sends the mission's
/// hidden brief as the scene of every reply and draws its opening picture
/// meanwhile. It ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).

@ProviderFor(Talk)
final talkProvider = TalkFamily._();

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]) and sends the collection's
/// name and description as the topic ([scenePick]); the Worker plans a
/// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
/// never the mnemonic story), the talk keeps only those, sends the mission's
/// hidden brief as the scene of every reply and draws its opening picture
/// meanwhile. It ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).
final class TalkProvider extends $NotifierProvider<Talk, TalkState> {
  /// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
  /// [collectionId] is the current collection. The talk takes the words a
  /// learning session would ([pickSessionWords]) and sends the collection's
  /// name and description as the topic ([scenePick]); the Worker plans a
  /// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
  /// never the mnemonic story), the talk keeps only those, sends the mission's
  /// hidden brief as the scene of every reply and draws its opening picture
  /// meanwhile. It ticks words from the learner's own replies only
  /// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
  /// Leaving without [finish] writes nothing (AC-22).
  TalkProvider._({required TalkFamily super.from, required String? super.argument})
      : super(
          retry: null,
          name: r'talkProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$talkHash();

  @override
  String toString() {
    return r'talkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Talk create() => Talk();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TalkState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TalkState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TalkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$talkHash() => r'a4a17ba45d8c99015428d95b3f73e3613ff488a2';

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]) and sends the collection's
/// name and description as the topic ([scenePick]); the Worker plans a
/// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
/// never the mnemonic story), the talk keeps only those, sends the mission's
/// hidden brief as the scene of every reply and draws its opening picture
/// meanwhile. It ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).

final class TalkFamily extends $Family with $ClassFamilyOverride<Talk, TalkState, TalkState, TalkState, String?> {
  TalkFamily._()
      : super(
          retry: null,
          name: r'talkProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
  /// [collectionId] is the current collection. The talk takes the words a
  /// learning session would ([pickSessionWords]) and sends the collection's
  /// name and description as the topic ([scenePick]); the Worker plans a
  /// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
  /// never the mnemonic story), the talk keeps only those, sends the mission's
  /// hidden brief as the scene of every reply and draws its opening picture
  /// meanwhile. It ticks words from the learner's own replies only
  /// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
  /// Leaving without [finish] writes nothing (AC-22).

  TalkProvider call(
    String? collectionId,
  ) =>
      TalkProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'talkProvider';
}

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]) and sends the collection's
/// name and description as the topic ([scenePick]); the Worker plans a
/// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
/// never the mnemonic story), the talk keeps only those, sends the mission's
/// hidden brief as the scene of every reply and draws its opening picture
/// meanwhile. It ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).

abstract class _$Talk extends $Notifier<TalkState> {
  late final _$args = ref.$arg as String?;
  String? get collectionId => _$args;

  TalkState build(
    String? collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TalkState, TalkState>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<TalkState, TalkState>, TalkState, Object?, Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
