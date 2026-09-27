import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// The popup package measures the dots' position once, when the menu shows.
/// Tapping the dots drops the keyboard, which moves a lower row down, so with
/// the keyboard up the menu must wait until it has closed -- otherwise it is
/// pinned to where the dots used to be.
void main() {
  late CustomPopupMenuController controller;
  var opened = 0;

  Future<void> pumpRow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    controller = CustomPopupMenuController();
    opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            height: 56,
            child: TranslationDotsButton(
              key: const ValueKey('dots'),
              controller: controller,
              onSelectTranslation: (_) {},
              onLoadTranslations: () async => null,
              onOpen: () => opened++,
              onClose: controller.hideMenu,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('keyboard down: the menu opens in the same tap', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byKey(const ValueKey('dots')));
    expect(controller.menuIsShowing, isTrue);
    expect(opened, greaterThan(0));
  });

  testWidgets('keyboard up: the menu waits for the keyboard to close',
      (tester) async {
    await pumpRow(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('dots')));
    await tester.pump();
    await tester.pump();
    expect(opened, greaterThan(0), reason: 'the keyboard is asked to close');
    expect(controller.menuIsShowing, isFalse,
        reason: 'still waiting for the keyboard');

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(controller.menuIsShowing, isTrue);

    await tester.pumpAndSettle();
    final dotsTop = tester.getTopLeft(find.byKey(const ValueKey('dots'))).dy;
    final menuBottom = tester
        .getBottomLeft(find.byWidgetPredicate(
            (w) => w is Material && w.color == Colors.black87))
        .dy;
    expect(menuBottom, lessThanOrEqualTo(dotsTop),
        reason: 'the menu sits above the dots where they are now');
  });

  testWidgets('keyboard that never reports zero: the menu still opens',
      (tester) async {
    await pumpRow(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('dots')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.menuIsShowing, isTrue);
  });
}
