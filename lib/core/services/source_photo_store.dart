import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/source_photo.dart';

/// Keeps the 1600 px copy of every photo the learner takes, as a file in the
/// app documents dir under `source_photos/` (good-looking-web sad §5, "kept
/// photo copy"). A kept photo lives as long as its session.
///
/// Like `SessionStore`, nothing here throws: failing to keep a photo must not
/// stop its words from reaching the list — the rows are just left untagged.
class SourcePhotoStore {
  static const _folder = 'source_photos';

  /// Parent of the photo folder; the app documents dir when null.
  final String? directory;

  SourcePhotoStore({this.directory});

  Future<Directory> _dir() async {
    final parent =
        directory ?? (await getApplicationDocumentsDirectory()).path;
    return Directory('$parent/$_folder');
  }

  Future<File> fileFor(SourcePhoto photo) async =>
      File('${(await _dir()).path}/${photo.fileName}');

  /// Writes [bytes] (a JPEG) under a fresh UUID and returns the reference, or
  /// null if the file could not be written.
  Future<SourcePhoto?> keep(Uint8List bytes, {DateTime? takenAt}) async {
    try {
      final dir = await _dir();
      await dir.create(recursive: true);
      final id = _uuidV4();
      final photo = SourcePhoto()
        ..id = id
        ..fileName = '$id.jpg'
        ..takenAt = takenAt ?? DateTime.now();
      await File('${dir.path}/${photo.fileName}').writeAsBytes(bytes, flush: true);
      return photo;
    } catch (e) {
      debugPrint('VOCAB: keeping the source photo failed: $e');
      return null;
    }
  }

  /// The kept bytes, or null when the file is gone.
  Future<Uint8List?> read(SourcePhoto photo) async {
    try {
      final file = await fileFor(photo);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(SourcePhoto photo) async {
    try {
      final file = await fileFor(photo);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }
}

/// A random (version 4) UUID. The photo id is declared to the Worker before
/// the bytes are uploaded (ADR-0006), so it must be unguessable.
String _uuidV4() {
  final random = Random.secure();
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
