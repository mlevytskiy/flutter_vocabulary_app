import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/services/subtitle_parser.dart';

/// words-from-subtitles T5: the phone strips a subtitle file to its spoken
/// lines before anything is sent (ADR-0002, AC-08, AC-10).
String _fixture(String name) =>
    File('test/fixtures/subtitles/$name').readAsStringSync();

void main() {
  test('SRT: numbers, timings, tags, captions, labels and music marks are gone; a cue is one line per speaker', () {
    expect(SubtitleParser.parse(_fixture('sample.srt'), extension: 'srt'), [
      'I was reluctant to leave, but the tide was coming in.',
      'Grab the rope!',
      "Don't let go.",
      'We sail at dawn',
      "We'll wait for the fog to lift.",
    ]);
  });

  test('Windows line endings and a byte-order mark read the same as plain newlines', () {
    final unix = _fixture('sample.srt').replaceAll('\r\n', '\n').replaceFirst('\uFEFF', '');
    final windows = '\uFEFF${unix.replaceAll('\n', '\r\n')}';
    expect(SubtitleParser.parse(windows, extension: 'srt'), SubtitleParser.parse(unix, extension: 'srt'));
    expect(SubtitleParser.parse(windows, extension: 'srt'), hasLength(5));
  });

  test('VTT: the header, NOTE and STYLE blocks, cue ids, settings, voice and class tags and entities are handled', () {
    expect(SubtitleParser.parse(_fixture('sample.vtt'), extension: '.VTT'), [
      'I was reluctant to leave, but the tide was coming in.',
      'Grab the rope & hold on!',
    ]);
  });

  test('a file with no timed cue, an empty file, or another extension gives nothing to send', () {
    expect(SubtitleParser.parse('', extension: 'srt'), isEmpty);
    expect(SubtitleParser.parse('Just some text\nwith no timings.\n', extension: 'srt'), isEmpty);
    expect(SubtitleParser.parse('WEBVTT\n\nNOTE only a note\n', extension: 'vtt'), isEmpty);
    expect(SubtitleParser.parse(_fixture('sample.srt'), extension: 'txt'), isEmpty);
    expect(SubtitleParser.parse('1\n00:00:01,000 --> 00:00:02,000\n[music]\n', extension: 'srt'), isEmpty);
  });

  test('a line over 200 characters is split at word boundaries, never cut mid-word', () {
    final long = List.filled(60, 'reluctant').join(' '); // 599 characters
    final lines = SubtitleParser.parse('1\n00:00:01,000 --> 00:00:02,000\n$long\n', extension: 'srt');
    expect(lines.length, 3);
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(SubtitleParser.maxLineChars));
      expect(line.split(' ').every((w) => w == 'reluctant'), isTrue);
    }
    expect(lines.join(' '), long);
  });

  test('a single word over 200 characters is hard-split', () {
    final word = 'a' * 450;
    final lines = SubtitleParser.parse('1\n00:00:01,000 --> 00:00:02,000\n$word\n', extension: 'srt');
    expect(lines.map((l) => l.length), [200, 200, 50]);
  });

  test('a 1 MB file strips to lines within the service limit of 1,048,576 bytes', () {
    final cue = StringBuffer();
    var size = 0;
    for (var i = 1; size < 1048576 - 200; i++) {
      final block = '$i\n00:00:01,000 --> 00:00:02,000\n<i>Ми чекали, поки туман розвіється — we waited.</i>\n\n';
      cue.write(block);
      size += utf8.encode(block).length;
    }
    final lines = SubtitleParser.parse(cue.toString(), extension: 'srt');
    expect(lines, isNotEmpty);
    final bytes = lines.fold<int>(0, (sum, l) => sum + utf8.encode(l).length);
    expect(bytes, lessThanOrEqualTo(1048576));
    expect(lines.every((l) => l.isNotEmpty && l.length <= 200), isTrue);
  });
}
