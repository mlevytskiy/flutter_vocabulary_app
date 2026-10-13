import 'dart:typed_data';

import '../models/session_source.dart';
import 'source_photo_store.dart';

/// The kept photo files' bytes, read once per source and kept in memory while
/// the app runs (side-bar-for-main-screen).
///
/// The photo panel's previews are made anew each time it opens. Reading the
/// 1600 px file again gave new bytes, so the image cache missed and every
/// photo was decoded again, in the very frames of the panel's opening. One
/// set of bytes per source keeps the image cache's key the same, so a photo
/// is decoded once per size. A failed read is not kept: it is tried again.
class SourcePhotoBytes {
  SourcePhotoBytes(this._store);

  final SourcePhotoStore _store;

  /// The most sources kept; the oldest read goes first.
  static const keep = 40;

  final _bytes = <String, Uint8List>{};
  final _reading = <String, Future<Uint8List?>>{};

  /// The bytes already read for [source], or null.
  Uint8List? peek(SessionSource source) => _bytes[source.id];

  /// The bytes of [source]'s file, read at most once while they are kept;
  /// null for a missing or unreadable file.
  Future<Uint8List?> read(SessionSource source) {
    final kept = _bytes[source.id];
    if (kept != null) return Future.value(kept);
    return _reading[source.id] ??= _store.read(source).then((bytes) {
      _reading.remove(source.id);
      if (bytes != null) {
        _bytes[source.id] = bytes;
        if (_bytes.length > keep) _bytes.remove(_bytes.keys.first);
      }
      return bytes;
    });
  }
}
