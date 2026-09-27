import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

/// PROBE B -- does a plain `hideMenu()` on the bound controller always remove
/// the overlay? No app widgets: the same controller instance is used for the
/// widget's whole life, so identity is held constant and only the *sequence*
/// of calls varies. If the overlay survives `hideMenu()` here too, the bug is
/// inside the package's listener/overlay handling, not in the controller map.
void main() {
  testWidgets('B: hideMenu on the bound controller', (tester) async {
    final controller = CustomPopupMenuController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: CustomPopupMenu(
            controller: controller,
            pressType: PressType.singleClick,
            menuBuilder: () => const SizedBox(
              width: 200,
              height: 100,
              child: ColoredBox(color: Colors.black87),
            ),
            child: const SizedBox(width: 40, height: 40, child: Text('dots')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    bool overlayUp() => find
        .byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.black87)
        .evaluate()
        .isNotEmpty;

    debugPrint('B: overlay before open        = ${overlayUp()}');
    await tester.tap(find.text('dots'));
    await tester.pumpAndSettle();
    debugPrint('B: overlay after open         = ${overlayUp()} showing=${controller.menuIsShowing}');

    controller.hideMenu();
    await tester.pump();
    debugPrint('B: overlay after hideMenu     = ${overlayUp()} showing=${controller.menuIsShowing}');

    // Same call again, in case the first was swallowed while the overlay was
    // still being inserted by the first frame's post-frame callback.
    await tester.pumpAndSettle();
    controller.hideMenu();
    await tester.pumpAndSettle();
    debugPrint('B: overlay after 2nd hideMenu = ${overlayUp()} showing=${controller.menuIsShowing}');

    // And the reopen/close cycle that the app actually performs.
    controller.showMenu();
    await tester.pumpAndSettle();
    debugPrint('B: overlay after showMenu     = ${overlayUp()}');
    controller.hideMenu();
    await tester.pumpAndSettle();
    debugPrint('B: overlay after hideMenu #2  = ${overlayUp()}');
  });
}
