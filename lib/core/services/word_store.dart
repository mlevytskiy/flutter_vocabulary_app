import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_pair.dart';

/// Persists the word list as one JSON-encoded string under a single
/// SharedPreferences key.
///
/// [load] never throws: a missing key, a non-JSON value, or JSON that isn't
/// the expected shape all come back as an empty list, so a corrupt store or
/// a future format change can never crash the app on launch.
class WordStore {
  static const _key = 'word_pairs_v1';

  Future<List<WordPair>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((m) => WordPair.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<WordPair> pairs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pairs.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
