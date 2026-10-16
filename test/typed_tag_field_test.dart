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
    this.mode = SuggestionMode.always,
    this.forgotten,
  });
  final TagKind kind;
  final List<String> tags;
  final List<TagSuggestion> suggestions;
  final SuggestionMode mode;
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
                mode: widget.mode,
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
  testWidgets('hint and helper per kind', (tester) async {
    await tester.pumpWidget(const _Host(kind: TagKind.origin));
    expect(find.text('Where does it come from?'), findsOneWidget);
    expect(find.text('e.g. Friends (series), a podcast, a trip to London'),
        findsOneWidget);
    await tester.pumpWidget(const _Host(kind: TagKind.topic));
    await tester.pump();
    expect(find.text('What is it about?'), findsOneWidget);
    expect(
        find.text('e.g. Food, Phrasal verbs, Job interview'), findsOneWidget);
  });

  testWidgets('TagChip look per kind', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: Column(children: [
        TagChip(kind: TagKind.origin, text: 'Film'),
        TagChip(kind: TagKind.topic, text: 'Food'),
      ])),
    ));
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tag), findsOneWidget);
  });

  testWidgets('a tapped suggestion is added and leaves the row',
      (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Food'), _preset('Work')],
    ));
    await tester.tap(find.byKey(TypedTagField.suggestionKey('Food')));
    await tester.pump();
    expect(find.byType(TagChip), findsOneWidget);
    expect(find.byKey(TypedTagField.suggestionKey('Food')), findsNothing);
    expect(find.byKey(TypedTagField.suggestionKey('Work')), findsOneWidget);
  });

  testWidgets('the row shows at most 8 suggestions', (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [for (var i = 0; i < 12; i++) _own('t$i')],
    ));
    expect(find.byType(ActionChip), findsNWidgets(8));
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
      suggestions: [_own('Food'), _preset('Work')],
      forgotten: forgotten,
    ));
    await _longPress(tester, find.byKey(TypedTagField.suggestionKey('Work')));
    expect(find.text('Forget this tag'), findsNothing);
    await _longPress(tester, find.byKey(TypedTagField.suggestionKey('Food')));
    expect(find.text('Forget this tag'), findsOneWidget);
    await tester.tap(find.text('Forget this tag'));
    await tester.pumpAndSettle();
    expect(forgotten, ['Food']);
  });

  testWidgets('whenFocused hides the row unfocused and shows it focused',
      (tester) async {
    await tester.pumpWidget(_Host(
      kind: TagKind.topic,
      suggestions: [_own('Food')],
      mode: SuggestionMode.whenFocused,
    ));
    expect(find.byKey(TypedTagField.suggestionKey('Food')), findsNothing);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(find.byKey(TypedTagField.suggestionKey('Food')), findsOneWidget);
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(find.byKey(TypedTagField.suggestionKey('Food')), findsNothing);
  });
}
