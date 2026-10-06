import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';

void main() {
  test('the app exercise list matches the Worker exercises.json entry by entry', () {
    final raw = File('vocab-photo-api/src/learn/exercises.json').readAsStringSync();
    final json = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    expect(json.length, 11);
    expect(exercises.length, json.length);
    for (var i = 0; i < json.length; i++) {
      expect(exercises[i].id, json[i]['id'], reason: 'id at $i');
      expect(exercises[i].name, json[i]['name'], reason: 'name at $i');
      expect(exercises[i].stage, json[i]['stage'], reason: 'stage at $i');
      expect(exercises[i].available, json[i]['available'], reason: 'available at $i');
    }
  });
}
