import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/services/tag_rules.dart';
import 'package:flutter_vocabulary_app/features/tags/tag_chip.dart';
import 'package:flutter_vocabulary_app/features/tags/typed_tag_field.dart';

/// collection-tags T9: TagChip and TypedTagField (AC-04, 07..12, 35).

class _Host extends StatefulWidget {
  const _Host({
    required this.kind,
    this.tags = const [],
    this.suggestions = const [],
    this.forgotten,
  });
  final TagKind kind;
  final List<String> tags;
  final List<TagSuggestion> suggestions;
  final List<String>? forgotten;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> tags = widget.tags;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TypedTagField(
                kind: widget.kind,
                tags: tags,
                suggestions: widget.suggestions,
                onChanged: (t) => setState(() => tags = t),
                onForget: widget.forgotten?.add,
                fieldKey: const Key('field'),
              ),
              const TextField(key: Key('other')),
            ]),
          ),
        ),
      );
}

TagSuggestion _own(String t) => (text: t, isPreset: false);
TagSuggestion _preset(String t) => (text: t, isPreset: true);

Future<void> _longPress(WidgetTester tester, Finder f) async {
  await tester.longPress(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the question per kind on top, no helper line', (tester) async {
    await tester.pumpWidget(const _Host(kind: TagKind.origin));
    expect(find.text('Where does it come from?'), findsOneWidget);
    expect(find.textContaining('e.g.'), findsNothing);
    await tester.pumpWidget(const _Host(kind: TagKind.topic));
    await tester.pump();
    expect(find.text('What is it about?'), findsOneWidget);
  });

  testWidgets('tags have no icons', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: Column(children: [
        TagChip(kind: TagKind.origin, text: 'Film'),
        TagChip(kind: TagKind.topic, text: 'Food'),
      ])),
    ));
    expect(find.byIcon(Icons.explore_outlined), findsNothing);
    expect(find.byIcon(Icons.tag), findsNothing);
  });

  testWidgets('startInEditMode opens in the edit state until Done',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypedTagField(
          kind: TagKind.topic,
          tags: const ['Food'],
          suggestions: const [],
          onChanged: (_) {},
          startInEditMode: true,
        ),
      ),
    ));
    expect(find.byKey(TypedTagField.doneKey), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    await tester.tap(find.byKey(TypedTagField.doneKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TypedTagField.doneKey), findsNothing);
  });

  testWidgets('view state: no delete, no Done; a tap opens the edit state',
      (tester) async {
    await tester.pumpWidget(const _Host(kind: TagKind.topic, tags: ['Food']));
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.byKey(TypedTagField.doneKey), findsNothing);
    await tester.tap(find.widgetWithText(TagChip, 'Food'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byKey(TypedTagField.doneKey), findsOneWidget);
    await tester.tap(find.byKey(TypedTagField.doneKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TypedTagField.doneKey), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets('a chip is removed in the edit state', (tester) async {
    await tester
        .pumpWidget(const _Host(kind: TagKind.topic, tags: ['Food', 'Work']));
    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.widgetWithText(TagChip, 'Food'),
        matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(find.byType(TagChip), findsOneWidget);
  });

  testWidgets('no suggestions until something is typed', (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Food'), _preset('Work')],
    ));
    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();
    expect(find.byKey(TypedTagField.optionKey('Food')), findsNothing);
    expect(find.byKey(TypedTagField.optionKey('Work')), findsNothing);
  });

  testWidgets('typing filters options by word start and adds on tap',
      (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Home cooking'), _own('Tacos')],
    ));
    await tester.enterText(find.byKey(const Key('field')), 'co');
    await tester.pumpAndSettle();
    expect(find.byKey(TypedTagField.optionKey('Home cooking')), findsOneWidget);
    expect(find.byKey(TypedTagField.optionKey('Tacos')), findsNothing);
    await tester.tap(find.byKey(TypedTagField.optionKey('Home cooking')));
    await tester.pumpAndSettle();
    expect(find.byType(TagChip), findsOneWidget);
  });

  testWidgets('the list shows at most 8 suggestions plus the new tag row',
      (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [for (var i = 0; i < 12; i++) _own('t$i')],
    ));
    await tester.enterText(find.byKey(const Key('field')), 't');
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      expect(find.byKey(TypedTagField.optionKey('t$i')), findsOneWidget);
    }
    expect(find.byKey(TypedTagField.optionKey('t8')), findsNothing);
    expect(find.byKey(TypedTagField.newOptionKey), findsOneWidget);
  });

  testWidgets('a text not in the list is added as a new tag', (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Food')],
    ));
    await tester.enterText(find.byKey(const Key('field')), 'Fo');
    await tester.pumpAndSettle();
    expect(find.text('New tag'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field')), 'food');
    await tester.pumpAndSettle();
    // Already a suggestion: no new tag row.
    expect(find.byKey(TypedTagField.newOptionKey), findsNothing);
    await tester.enterText(find.byKey(const Key('field')), 'Street food');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TypedTagField.newOptionKey));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TagChip, 'Street food'), findsOneWidget);
  });

  testWidgets('a tap outside keeps the typed tag', (tester) async {
    await tester.pumpWidget(const _Host(kind: TagKind.topic));
    await tester.enterText(find.byKey(const Key('field')), 'Kitchen');
    await tester.tapAt(const Offset(400, 580));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TagChip, 'Kitchen'), findsOneWidget);
    expect(find.byKey(TypedTagField.doneKey), findsNothing);
  });

  testWidgets('a typed tag keeps the known spelling, ignoring case',
      (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Phrasal verbs')],
    ));
    await tester.enterText(find.byKey(const Key('field')), 'phrasal VERBS');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.widgetWithText(TagChip, 'Phrasal verbs'), findsOneWidget);
  });

  testWidgets('a bad tag shows the message and adds nothing', (tester) async {
    await tester.pumpWidget(const _Host(kind: TagKind.topic));
    await tester.enterText(find.byKey(const Key('field')), 'x' * 31);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text(tagProblemMessage), findsOneWidget);
    expect(find.byType(TagChip), findsNothing);
  });

  testWidgets('the 11th tag is refused with the limit message', (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      tags: [for (var i = 0; i < 10; i++) 'tag$i'],
    ));
    await tester.enterText(find.byKey(const Key('field')), 'eleventh');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text(tagLimitMessage), findsOneWidget);
    expect(find.byType(TagChip), findsNWidgets(10));
  });

  testWidgets('long-press Forget only on own tags', (tester) async {
    final forgotten = <String>[];
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Food'), _preset('Fruit')],
      forgotten: forgotten,
    ));
    await tester.enterText(find.byKey(const Key('field')), 'f');
    await tester.pumpAndSettle();
    await _longPress(tester, find.byKey(TypedTagField.optionKey('Food')));
    expect(find.text('Forget this tag'), findsOneWidget);
    await tester.tap(find.text('Forget this tag'));
    await tester.pumpAndSettle();
    expect(forgotten, ['Food']);
    await _longPress(tester, find.byKey(TypedTagField.optionKey('Fruit')));
    expect(find.text('Forget this tag'), findsNothing);
  });
}
