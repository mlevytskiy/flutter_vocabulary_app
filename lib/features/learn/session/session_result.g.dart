// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_result.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lastSessionResultHash() => r'0ac13e7cc5e8c6d6c9bddc45d395a62f80133b55';

/// The last finished session, read by the results screen (sad §5.1). Written
/// by the learning session and by Talk at their end; kept alive so the
/// results screen and "Practise N shaky" / "Next group" can read it.
///
/// Copied from [LastSessionResult].
@ProviderFor(LastSessionResult)
final lastSessionResultProvider =
    NotifierProvider<LastSessionResult, SessionResult?>.internal(
  LastSessionResult.new,
  name: r'lastSessionResultProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lastSessionResultHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LastSessionResult = Notifier<SessionResult?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
