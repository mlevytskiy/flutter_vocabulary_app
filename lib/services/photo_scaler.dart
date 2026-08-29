import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Downscales photos on a single long-lived background isolate, using the
/// platform's native image codecs (via [flutter_image_compress], backed by
/// Objective-C on iOS and Kotlin on Android) instead of a pure-Dart decoder.
///
/// The isolate is spawned once, at app startup (see `main.dart`), and then
/// reused for every photo, avoiding the cost of spawning a fresh isolate per
/// request and keeping all decode/resize/encode work off the UI thread.
class PhotoScaler {
  PhotoScaler._();

  static final PhotoScaler instance = PhotoScaler._();

  Completer<SendPort>? _readyPort;
  final Map<int, Completer<Uint8List>> _pending = {};
  int _nextRequestId = 0;

  /// Spawns the background isolate. Call this once, as early as possible in
  /// [main] (before `runApp`). Safe to call multiple times; later calls
  /// reuse the isolate already being started.
  Future<void> start() async {
    if (_readyPort != null) {
      await _readyPort!.future;
      return;
    }
    final readyPort = Completer<SendPort>();
    _readyPort = readyPort;

    final receivePort = ReceivePort();
    final rootIsolateToken = RootIsolateToken.instance!;

    await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateStartParams(receivePort.sendPort, rootIsolateToken),
      debugName: 'photo-scaler',
    );

    receivePort.listen((dynamic message) {
      if (message is SendPort) {
        readyPort.complete(message);
        return;
      }
      if (message is _ResizeResult) {
        final completer = _pending.remove(message.requestId);
        if (completer == null) return;
        if (message.error != null) {
          completer.completeError(Exception(message.error));
        } else {
          completer.complete(message.bytes);
        }
      }
    });

    await readyPort.future;
  }

  /// Scales [bytes] so its *shorter* side becomes [minSide] pixels, keeping
  /// the aspect ratio (so the longer side ends up bigger than [minSide]).
  /// Images whose shorter side is already <= [minSide] are left at their
  /// original dimensions (only re-encoded at [quality]).
  Future<Uint8List> resizeToMinSide(
    Uint8List bytes, {
    int minSide = 640,
    int quality = 85,
  }) async {
    await start();
    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _pending[requestId] = completer;
    final sendPort = await _readyPort!.future;
    sendPort.send(_ResizeRequest(requestId, bytes, minSide, quality));
    return completer.future;
  }
}

class _IsolateStartParams {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;
  _IsolateStartParams(this.mainSendPort, this.rootIsolateToken);
}

class _ResizeRequest {
  final int requestId;
  final Uint8List bytes;
  final int minSide;
  final int quality;
  _ResizeRequest(this.requestId, this.bytes, this.minSide, this.quality);
}

class _ResizeResult {
  final int requestId;
  final Uint8List? bytes;
  final String? error;
  _ResizeResult(this.requestId, this.bytes, this.error);
}

void _isolateEntryPoint(_IsolateStartParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  final port = ReceivePort();
  params.mainSendPort.send(port.sendPort);

  port.listen((dynamic message) async {
    if (message is! _ResizeRequest) return;
    try {
      // minWidth == minHeight makes flutter_image_compress scale down until
      // the *shorter* side hits that bound (never upscales), which is
      // exactly the "shorter side -> minSide, longer side proportional"
      // behavior we want.
      final compressed = await FlutterImageCompress.compressWithList(
        message.bytes,
        minWidth: message.minSide,
        minHeight: message.minSide,
        quality: message.quality,
        format: CompressFormat.jpeg,
      );
      params.mainSendPort.send(
        _ResizeResult(message.requestId, compressed, null),
      );
    } catch (e) {
      params.mainSendPort.send(
        _ResizeResult(message.requestId, null, e.toString()),
      );
    }
  });
}
