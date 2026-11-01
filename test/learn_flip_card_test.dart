import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/session/flip_card.dart';

/// learn-flow-cards (owner, 2026-11-01): the 3D card flip.
void main() {
  Widget host(bool flipped) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: FlipCard(
                flipped: flipped,
                front: const Text('front face', key: ValueKey('front')),
                back: const Text('back face', key: ValueKey('back')),
              ),
            ),
          ),
        ),
      );

  /// The card's turn about its vertical axis, from its transform.
  double turnOf(WidgetTester tester) {
    final transform = tester
        .widget<Transform>(find.descendant(of: find.byType(FlipCard), matching: find.byType(Transform)).first)
        .transform;
    // rotateY puts cos(angle) at (0,0) and sin(angle) at (0,2) (row, column).
    return math.atan2(-transform.entry(2, 0), transform.entry(0, 0));
  }

  testWidgets('front first; it turns in 3D and shows the back, read the right way round', (tester) async {
    await tester.pumpWidget(host(false));
    expect(find.text('front face'), findsOneWidget);
    expect(find.text('back face'), findsNothing);

    await tester.pumpWidget(host(true));
    // A quarter into the turn: still the front, turned part way.
    await tester.pump(flipDuration * 0.3);
    expect(find.text('front face'), findsOneWidget);
    expect(find.text('back face'), findsNothing);
    final early = turnOf(tester);
    expect(early, greaterThan(0.05));
    expect(early, lessThan(math.pi / 2));

    // Past the half turn: the back, mirrored back (it comes in from the
    // other side and ends square, not mirrored).
    await tester.pump(flipDuration * 0.4);
    expect(find.text('front face'), findsNothing);
    expect(find.text('back face'), findsOneWidget);
    expect(turnOf(tester).abs(), lessThan(math.pi / 2));

    await tester.pumpAndSettle();
    expect(find.text('back face'), findsOneWidget);
    expect(turnOf(tester).abs(), lessThan(1e-6));
  });

  testWidgets('the next card shows its front at once', (tester) async {
    await tester.pumpWidget(host(true));
    expect(find.text('back face'), findsOneWidget);
    await tester.pumpWidget(host(false));
    expect(find.text('front face'), findsOneWidget);
    expect(find.text('back face'), findsNothing);
  });

  testWidgets('it takes about half a second', (tester) async {
    expect(flipDuration.inMilliseconds, inInclusiveRange(450, 600));
  });
}
