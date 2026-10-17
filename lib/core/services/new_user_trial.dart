import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Show me the app as a new user" (new-user-trial, owner 2026-10-17): puts
/// all the user's data aside so the app starts as on a fresh install, and
/// brings it back later, deleting what was entered in between.
///
/// The user's data is everything in the app documents folder (the `vocab`
/// database, kept photos, story pictures) plus every shared preference. The
/// backup lives outside that folder, in the app support folder under
/// `new_user_backup/`: `documents/` holds the moved files, `prefs.json` the
/// preferences, `taken_at` when it was made. Its presence is the "trial on"
/// state, so it survives the preferences being cleared.
///
/// [start] and [restore] close the database first; the caller must have
/// dropped everything that uses it (see `AppRestarter`).
class NewUserTrial {
  NewUserTrial({
    Future<Directory> Function()? documents,
    Future<Directory> Function()? support,
    Future<void> Function()? closeDatabase,
  })  : _documents = documents ?? getApplicationDocumentsDirectory,
        _support = support ?? getApplicationSupportDirectory,
        _closeDatabase = closeDatabase ?? _closeVocab;

  static const _folder = 'new_user_backup';

  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _support;
  final Future<void> Function() _closeDatabase;

  static Future<void> _closeVocab() async {
    await Isar.getInstance('vocab')?.close();
  }

  Future<Directory> _backup() async =>
      Directory('${(await _support()).path}/$_folder');

  /// When the backup was made, or null when there is none (no trial on).
  Future<DateTime?> backupTakenAt() async {
    try {
      final stamp = File('${(await _backup()).path}/taken_at');
      if (!await stamp.exists()) return null;
      return DateTime.tryParse((await stamp.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  /// Moves the user's data into the backup and leaves the app empty. Does
  /// nothing when a backup is already there, so a second start can never
  /// overwrite the real data with a trial's.
  Future<void> start() async {
    if (await backupTakenAt() != null) return;
    await _closeDatabase();
    final backup = await _backup();
    if (await backup.exists()) await backup.delete(recursive: true);
    final files = Directory('${backup.path}/documents');
    await files.create(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    await File('${backup.path}/prefs.json')
        .writeAsString(jsonEncode(_snapshot(prefs)), flush: true);
    await _moveContents(await _documents(), files);
    await prefs.clear();
    // Written last: a backup without it was cut short and is not offered.
    await File('${backup.path}/taken_at')
        .writeAsString(DateTime.now().toIso8601String(), flush: true);
  }

  /// Deletes everything entered since [start] and puts the backup back.
  Future<void> restore() async {
    if (await backupTakenAt() == null) return;
    await _closeDatabase();
    final backup = await _backup();
    final documents = await _documents();
    await _deleteContents(documents);
    await _moveContents(Directory('${backup.path}/documents'), documents);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final saved = File('${backup.path}/prefs.json');
    if (await saved.exists()) {
      await _apply(prefs,
          jsonDecode(await saved.readAsString()) as Map<String, dynamic>);
    }
    await backup.delete(recursive: true);
  }

  // Each value tagged with its type, so a restore writes it back as it was.
  static Map<String, Object> _snapshot(SharedPreferences prefs) => {
        for (final key in prefs.getKeys())
          if (prefs.get(key) case final Object value)
            key: switch (value) {
              bool() => {'bool': value},
              int() => {'int': value},
              double() => {'double': value},
              String() => {'string': value},
              _ => {'list': prefs.getStringList(key) ?? const <String>[]},
            },
      };

  static Future<void> _apply(
      SharedPreferences prefs, Map<String, dynamic> snapshot) async {
    for (final MapEntry(:key, :value) in snapshot.entries) {
      final tagged = value as Map<String, dynamic>;
      final v = tagged.values.first;
      await switch (tagged.keys.first) {
        'bool' => prefs.setBool(key, v as bool),
        'int' => prefs.setInt(key, v as int),
        'double' => prefs.setDouble(key, (v as num).toDouble()),
        'string' => prefs.setString(key, v as String),
        _ => prefs.setStringList(key, (v as List).cast<String>()),
      };
    }
  }

  static Future<void> _moveContents(Directory from, Directory to) async {
    if (!await from.exists()) return;
    await to.create(recursive: true);
    await for (final entity in from.list(followLinks: false)) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final target = '${to.path}/$name';
      try {
        await entity.rename(target);
      } on FileSystemException {
        // Another volume: copy, then delete.
        await _copy(entity, target);
        await entity.delete(recursive: true);
      }
    }
  }

  static Future<void> _copy(FileSystemEntity entity, String target) async {
    if (entity is File) {
      await entity.copy(target);
    } else if (entity is Directory) {
      await Directory(target).create(recursive: true);
      await for (final child in entity.list(followLinks: false)) {
        final name = child.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        await _copy(child, '$target/$name');
      }
    }
  }

  static Future<void> _deleteContents(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        debugPrint('VOCAB: clearing ${entity.path} failed: $e');
      }
    }
  }
}
