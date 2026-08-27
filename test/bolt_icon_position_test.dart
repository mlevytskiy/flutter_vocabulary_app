// Regression test for the AI-fill bolt icon's on-screen geometry: it must
// never visibly shift as the user types past the reveal threshold or as
// BoltState advances through idle -> loadingPrimary -> loadingSecondary ->
// ready. Mirrors the exact widget tree used in word_input_screen.dart's
// `_buildItem`: a plain Material+InkWell wrapper for idle/loading states,
// swapping to a `CustomPopupMenu` wrapper (anchored translation-alternatives
// popup) once the ready state is reached.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import 'package:flutter_vocabulary_app/widgets/animated_bolt_icon.dart'
    show BoltState;
import 'package:flutter_vocabulary_app/widgets/lottie_bolt_icon.dart';
import 'package:flutter_vocabulary_app/widgets/synced_text_field_row.dart';

void main() {
  testWidgets('bolt icon bounding box is stable across states/text-length',
      (tester) async {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    BoltState state = BoltState.idle;
    late StateSetter setLocalState;
    // A stable GlobalKey is cheap defense-in-depth for letting
    // LottieBoltIcon's element (and its Lottie AnimationController) survive
    // rebuilds -- see the matching key usage in word_input_screen.dart.
    final boltIconKey = GlobalKey();
    final popupController = CustomPopupMenuController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) {
                setLocalState = setState;
                return Stack(
                  children: [
                    SyncedTextFieldRow(
                      leftController: wordController,
                      rightController: translationController,
                      leftLabel: 'Word',
                      rightLabel: 'Translation',
                      leftHint: 'Word',
                      rightHint: 'Translation',
                    ),
                    if (wordController.text.length >= 2)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: state == BoltState.ready
                            ? CustomPopupMenu(
                                controller: popupController,
                                pressType: PressType.singleClick,
                                showArrow: true,
                                arrowColor: Colors.black87,
                                arrowSize: 10,
                                barrierColor: Colors.transparent,
                                verticalMargin: 6,
                                menuBuilder: () => const SizedBox.shrink(),
                                child: LottieBoltIcon(
                                    key: boltIconKey,
                                    state: state,
                                    starCount: 4),
                              )
                            : Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {},
                                  child: LottieBoltIcon(
                                      key: boltIconKey,
                                      state: state,
                                      starCount: 4),
                                ),
                              ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 1 char: icon not shown yet.
    wordController.text = 'a';
    setLocalState(() {});
    await tester.pump();
    expect(find.byType(LottieBoltIcon), findsNothing);

    // 2 chars: icon appears (idle state). This is the reference geometry
    // every later step is compared against.
    wordController.text = 'ab';
    setLocalState(() {});
    await tester.pump(const Duration(milliseconds: 50));
    final referenceTopLeft = tester.getTopLeft(find.byType(LottieBoltIcon));
    final referenceSize = tester.getSize(find.byType(LottieBoltIcon));

    void expectUnchangedGeometry() {
      expect(tester.getTopLeft(find.byType(LottieBoltIcon)), referenceTopLeft);
      expect(tester.getSize(find.byType(LottieBoltIcon)), referenceSize);
    }

    // Typing further must not move/resize it.
    wordController.text = 'abcdef';
    setLocalState(() {});
    await tester.pump(const Duration(milliseconds: 50));
    expectUnchangedGeometry();

    // loadingPrimary / loadingSecondary: same wrapper, just a state change.
    state = BoltState.loadingPrimary;
    setLocalState(() {});
    await tester.pump(const Duration(milliseconds: 50));
    expectUnchangedGeometry();

    state = BoltState.loadingSecondary;
    setLocalState(() {});
    await tester.pump(const Duration(milliseconds: 50));
    expectUnchangedGeometry();

    // Capture State identity just before the ready transition, to prove the
    // GlobalKey actually preserves it (rather than silently recreating it,
    // which would skip the bloom-into-stars animation entirely).
    final stateBefore = boltIconKey.currentState;

    // ready: the bloom-into-stars transition -- the critical check.
    state = BoltState.ready;
    setLocalState(() {});
    await tester.pump(const Duration(milliseconds: 50));
    expectUnchangedGeometry();
    expect(boltIconKey.currentState, same(stateBefore),
        reason: 'LottieBoltIcon state must survive the idle -> ready '
            'transition so its bloom animation actually plays instead of '
            'being silently skipped.');

    // Let the bloom's crossfade-dip timer and animateTo() finish and settle
    // into the (intentionally endless) stars_idle_loop repeat -- a bounded
    // pump is used instead of pumpAndSettle since that loop never
    // terminates by design.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expectUnchangedGeometry();
  });
}
