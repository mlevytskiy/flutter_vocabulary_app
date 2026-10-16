// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dialogue_push.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dialoguePushHash() => r'a6d78cc83dcc3a8c010253f80a955eea0a4bb2f7';

/// Delivers what the sessions with a shared link still owe it
/// (get-words-from-subtitles-improvment ADR-0005): each pending import's rows
/// and dialogues, then each pending scene picture whose dialogue the page
/// has. Runs once on app start (read in `app.dart`), whenever the current
/// session gains something to deliver, and again with growing pauses while
/// anything failed. The state lives on the `FilmDialogue`s, so closing the
/// app loses nothing. Never throws.
///
/// Copied from [DialoguePush].
@ProviderFor(DialoguePush)
final dialoguePushProvider = NotifierProvider<DialoguePush, void>.internal(
  DialoguePush.new,
  name: r'dialoguePushProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dialoguePushHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DialoguePush = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
