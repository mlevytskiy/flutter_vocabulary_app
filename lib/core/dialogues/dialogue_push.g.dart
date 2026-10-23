// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dialogue_push.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Delivers what the sessions with a shared link still owe it
/// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
/// and dialogues, then each pending scene picture whose dialogue the page
/// has. Runs once on app start (read in `app.dart`), whenever the current
/// session gains something to deliver, and again with growing pauses while
/// anything failed. The state lives on the `FilmDialogue`s, so closing the
/// app loses nothing. Never throws.

@ProviderFor(DialoguePush)
final dialoguePushProvider = DialoguePushProvider._();

/// Delivers what the sessions with a shared link still owe it
/// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
/// and dialogues, then each pending scene picture whose dialogue the page
/// has. Runs once on app start (read in `app.dart`), whenever the current
/// session gains something to deliver, and again with growing pauses while
/// anything failed. The state lives on the `FilmDialogue`s, so closing the
/// app loses nothing. Never throws.
final class DialoguePushProvider extends $NotifierProvider<DialoguePush, void> {
  /// Delivers what the sessions with a shared link still owe it
  /// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
  /// and dialogues, then each pending scene picture whose dialogue the page
  /// has. Runs once on app start (read in `app.dart`), whenever the current
  /// session gains something to deliver, and again with growing pauses while
  /// anything failed. The state lives on the `FilmDialogue`s, so closing the
  /// app loses nothing. Never throws.
  DialoguePushProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dialoguePushProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dialoguePushHash();

  @$internal
  @override
  DialoguePush create() => DialoguePush();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$dialoguePushHash() => r'1738fb1e95763e192c394fe62768771c8469b535';

/// Delivers what the sessions with a shared link still owe it
/// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
/// and dialogues, then each pending scene picture whose dialogue the page
/// has. Runs once on app start (read in `app.dart`), whenever the current
/// session gains something to deliver, and again with growing pauses while
/// anything failed. The state lives on the `FilmDialogue`s, so closing the
/// app loses nothing. Never throws.

abstract class _$DialoguePush extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<void, void>, void, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
