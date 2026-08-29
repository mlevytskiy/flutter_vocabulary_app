import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Downscales photos using the platform's native image codecs (via
/// [flutter_image_compress], backed by Objective-C on iOS and Kotlin on
/// Android) instead of a pure-Dart decoder. Takes a file path and lets the
/// native side read the file itself, rather than reading it into a Dart
/// [Uint8List] first.
///
/// The work is dispatched to a single long-lived background isolate, spawned
/// once at app startup (see `main.dart`) and reused for every photo.
///
/// Every step is bounded by a timeout and falls back to compressing on the
/// current isolate: platform-channel calls from a background isolate depend on
/// [BackgroundIsolateBinaryMessenger], which can fail in edge cases such as the
/// process being restarted to serve a content provider. The native plugin does
/// its decoding on its own background thread either way, so the fallback still
/// keeps the heavy work off the UI thread — it must never leave the caller
/// hanging forever.
class PhotoScaler {
  PhotoScaler._();

  static final PhotoScaler instance = PhotoScaler._();

  static const Duration _startTimeout = Duration(seconds: 5);
  static const Duration _resizeTimeout = Duration(seconds: 20);

  Completer<SendPort>? _readyPort;
  final Map<int, Completer<Uint8List>> _pending = {};
  int _nextRequestId = 0;

  /// Spawns the background isolate. Call this once, as early as possible in
  /// [main] (before `runApp`). Safe to call multiple times; later calls
  /// reuse the isolate already being started.
  Future<void> start() async {
    try {
      await _ensureStarted().timeout(_startTimeout);
    } catch (e) {
      debugPrint('VOCAB: PhotoScaler.start failed: $e');
    }
  }

  Future<SendPort> _ensureStarted() {
    final existing = _readyPort;
    if (existing != null) return existing.future;

    final readyPort = Completer<SendPort>();
    _readyPort = readyPort;

    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    void failStart(Object error) {
      if (!readyPort.isCompleted) readyPort.completeError(error);
      // Let the next request spawn a fresh isolate rather than reusing a
      // permanently broken one.
      if (_readyPort == readyPort) _readyPort = null;
      receivePort.close();
      errorPort.close();
      exitPort.close();
    }

    // Without these the isolate can die before sending its port and nothing
    // would ever complete the future.
    errorPort.listen((dynamic error) {
      debugPrint('VOCAB: PhotoScaler isolate error: $error');
      failStart(Exception('photo-scaler isolate error: $error'));
    });
    exitPort.listen((dynamic _) {
      if (!readyPort.isCompleted) {
        debugPrint('VOCAB: PhotoScaler isolate exited before becoming ready');
        failStart(Exception('photo-scaler isolate exited during startup'));
      }
    });

    receivePort.listen((dynamic message) {
      if (message is SendPort) {
        debugPrint('VOCAB: PhotoScaler isolate ready');
        if (!readyPort.isCompleted) readyPort.complete(message);
        return;
      }
      if (message is _ResizeResult) {
        final completer = _pending.remove(message.requestId);
        if (completer == null || completer.isCompleted) return;
        if (message.error != null) {
          completer.completeError(Exception(message.error));
        } else {
          // materialize() takes ownership of the transferred buffer with no
          // copy, unlike sending a plain Uint8List (which the VM copies).
          completer.complete(message.data!.materialize().asUint8List());
        }
      }
    });

    Isolate.spawn(
      _isolateEntryPoint,
      _IsolateStartParams(receivePort.sendPort, RootIsolateToken.instance!),
      debugName: 'photo-scaler',
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    ).catchError((Object e) {
      failStart(e);
      return Isolate.current;
    });

    return readyPort.future;
  }

  /// Scales the image at [path] so its *shorter* side becomes [minSide]
  /// pixels, keeping the aspect ratio (so the longer side ends up bigger
  /// than [minSide]). Images whose shorter side is already <= [minSide] are
  /// left at their original dimensions (only re-encoded at [quality]).
  ///
  /// Takes a file path rather than pre-read bytes: the native plugin reads
  /// the file itself (on its own thread either way), so this avoids an extra
  /// full-file read+copy on the Dart side, and avoids copying the (much
  /// larger, pre-compression) original bytes across the isolate boundary.
  Future<Uint8List> resizeFileToMinSide(
    String path, {
    int minSide = 640,
    int quality = 85,
  }) async {
    final requestId = _nextRequestId++;
    try {
      final sendPort = await _ensureStarted().timeout(_startTimeout);
      final completer = Completer<Uint8List>();
      _pending[requestId] = completer;
      sendPort.send(_ResizeRequest(requestId, path, minSide, quality));
      final result = await completer.future.timeout(_resizeTimeout);
      debugPrint('VOCAB: resized on isolate -> ${result.lengthInBytes} bytes');
      return result;
    } catch (e) {
      _pending.remove(requestId);
      debugPrint('VOCAB: isolate resize failed ($e); compressing directly');
      final result = await _compress(path, minSide, quality)
          .timeout(_resizeTimeout);
      debugPrint('VOCAB: resized directly -> ${result.lengthInBytes} bytes');
      return result;
    }
  }
}

Future<Uint8List> _compress(String path, int minSide, int quality) async {
  // minWidth == minHeight makes flutter_image_compress scale down until the
  // *shorter* side hits that bound (never upscales), which is exactly the
  // "shorter side -> minSide, longer side proportional" behavior we want.
  final result = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: minSide,
    minHeight: minSide,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  if (result == null) {
    throw Exception('flutter_image_compress returned no data for $path');
  }
  return result;
}

class _IsolateStartParams {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;
  _IsolateStartParams(this.mainSendPort, this.rootIsolateToken);
}

class _ResizeRequest {
  final int requestId;
  final String path;
  final int minSide;
  final int quality;
  _ResizeRequest(this.requestId, this.path, this.minSide, this.quality);
}

class _ResizeResult {
  final int requestId;
  final TransferableTypedData? data;
  final String? error;
  _ResizeResult(this.requestId, this.data, this.error);
}

void _isolateEntryPoint(_IsolateStartParams params) async {
  final port = ReceivePort();
  // Send the port before anything that can fail, so a failure here surfaces as
  // a per-request error rather than a startup that never completes.
  params.mainSendPort.send(port.sendPort);

  var messengerReady = true;
  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);
  } catch (e) {
    messengerReady = false;
  }

  port.listen((dynamic message) async {
    if (message is! _ResizeRequest) return;
    if (!messengerReady) {
      params.mainSendPort.send(
        _ResizeResult(
          message.requestId,
          null,
          'background isolate has no platform channel',
        ),
      );
      return;
    }
    try {
      final compressed =
          await _compress(message.path, message.minSide, message.quality);
      // Transfers ownership of the buffer to the main isolate instead of
      // copying it, since a plain Uint8List would be copied by the VM when
      // sent across the isolate boundary.
      params.mainSendPort.send(
        _ResizeResult(
          message.requestId,
          TransferableTypedData.fromList([compressed]),
          null,
        ),
      );
    } catch (e) {
      params.mainSendPort.send(
        _ResizeResult(message.requestId, null, e.toString()),
      );
    }
  });
}
