import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/features/word_input/collection_tag_line.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

Widget _host(CollectionTagLine line) => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('t'), bottom: line),
      ),
    );

void main() {
  testWidgets('no tags take no height', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const line = CollectionTagLine(originTags: [], topicTags: [], onTap: _noop);
    await tester.pumpWidget(_host(line));
    await tester.pumpAndSettle();
    expect(line.preferredSize.height, 0);
    expect(tester.getSize(find.byType(CollectionTagLine)).height, 0);
  });

  testWidgets('tags give 40 dp, origin first, tap reports kind and text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final taps = <(TagKind, String)>[];
    final line = CollectionTagLine(
      originTags: const ['Quizlet'],
      topicTags: const ['travel'],
      onTap: (k, t) => taps.add((k, t)),
    );
    await tester.pumpWidget(_host(line));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CollectionTagLine)).height, 40);
    expect(tester.getTopLeft(find.text('Quizlet')).dx,
        lessThan(tester.getTopLeft(find.text('travel')).dx));
    await tester.tap(find.text('travel'));
    await tester.tap(find.text('Quizlet'));
    expect(taps, [(TagKind.topic, 'travel'), (TagKind.origin, 'Quizlet')]);
  });

  test('CollectionsRoute location carries the tag fields', () {
    final uri = Uri.parse(
        const CollectionsRoute(tagKind: TagKind.topic, tag: 'a b').location);
    expect(uri.queryParameters['tag'], 'a b');
    expect(uri.queryParameters['tag-kind'], 'topic');
    expect(const CollectionsRoute().location, isNot(contains('?')));
  });
}

void _noop(TagKind k, String t) {}
