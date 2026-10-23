// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_result.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last finished session, read by the results screen (sad §5.1). Written
/// by the learning session and by Talk at their end; kept alive so the
/// results screen and "Practise N shaky" / "Next group" can read it.

@ProviderFor(LastSessionResult)
final lastSessionResultProvider = LastSessionResultProvider._();

/// The last finished session, read by the results screen (sad §5.1). Written
/// by the learning session and by Talk at their end; kept alive so the
/// results screen and "Practise N shaky" / "Next group" can read it.
final class LastSessionResultProvider
    extends $NotifierProvider<LastSessionResult, SessionResult?> {
  /// The last finished session, read by the results screen (sad §5.1). Written
  /// by the learning session and by Talk at their end; kept alive so the
  /// results screen and "Practise N shaky" / "Next group" can read it.
  LastSessionResultProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'lastSessionResultProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$lastSessionResultHash();

  @$internal
  @override
  LastSessionResult create() => LastSessionResult();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionResult?>(value),
    );
  }
}

String _$lastSessionResultHash() => r'0ac13e7cc5e8c6d6c9bddc45d395a62f80133b55';

/// The last finished session, read by the results screen (sad §5.1). Written
/// by the learning session and by Talk at their end; kept alive so the
/// results screen and "Practise N shaky" / "Next group" can read it.

abstract class _$LastSessionResult extends $Notifier<SessionResult?> {
  SessionResult? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionResult?, SessionResult?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<SessionResult?, SessionResult?>,
        SessionResult?,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
