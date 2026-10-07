import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Shrinks [bytes] to a JPEG at [quality] (1-100); null when it cannot.
typedef PictureCompressor = Future<Uint8List?> Function(
    Uint8List bytes, int quality);

Future<Uint8List?> _compressJpeg(Uint8List bytes, int quality) =>
    FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: quality,
      format: CompressFormat.jpeg,
    );

/// Keeps each story run's pictures on the phone, as files in the app
/// documents dir under `mnemonic_pictures/<runId>-<attempt>.jpg`
/// (mnemonic-story sad §5). A run's whole footprint stays within 3 MB
/// (spec §6, Storage), so a picture is compressed and, if still too big,
/// compressed harder.
///
/// Like `SourcePhotoStore`, nothing here throws: a picture that could not be
/// kept is just reported as not kept.
class StoryPictureStore {
  static const _folder = 'mnemonic_pictures';

  /// The most one picture may take on the device.
  static const maxBytes = 3 * 1024 * 1024;

  static const _qualities = [85, 70, 55, 40, 25];

  /// Parent of the picture folder; the app documents dir when null.
  final String? directory;
  final PictureCompressor _compress;

  StoryPictureStore({this.directory, PictureCompressor? compress})
      : _compress = compress ?? _compressJpeg;

  Future<File> _file(String runId, int attempt) async {
    final parent =
        directory ?? (await getApplicationDocumentsDirectory()).path;
    return File('$parent/$_folder/$runId-$attempt.jpg');
  }

  /// Compresses [bytes] and writes them; returns the file's path, or null
  /// when the picture could not be made small enough or written.
  Future<String?> write(String runId, int attempt, Uint8List bytes) async {
    try {
      Uint8List? small;
      for (final quality in _qualities) {
        final out = await _compress(bytes, quality);
        if (out != null && out.isNotEmpty && out.length <= maxBytes) {
          small = out;
          break;
        }
      }
      if (small == null) return null;
      final file = await _file(runId, attempt);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(small, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('VOCAB: keeping the story picture failed: $e');
      return null;
    }
  }

  /// The kept bytes, or null when the file is gone.
  Future<Uint8List?> read(String runId, int attempt) async {
    try {
      final file = await _file(runId, attempt);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(String runId, int attempt) async {
    try {
      return await (await _file(runId, attempt)).exists();
    } catch (_) {
      return false;
    }
  }
}
