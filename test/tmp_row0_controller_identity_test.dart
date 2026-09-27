import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// Mirrors `word_input_screen.dart`'s `_popupControllers` lifecycle:
/// `putIfAbsent(index, () => ...)` at build time, `clear()` on restore/reorder.
///
/// The screen keeps whatever controller it handed the row, but the package
/// binds `widget.controller` once in `initState` and never re-reads it. So if
/// the map is cleared and rebuilt while the State stays alive, row 0 (the only
/// row that already existed) keeps listening to the discarded controller while
/// rows 1..N get fresh ones. This test checks exactly that.
class Host extends StatefulWidget {
  const Host({super.key, required this.rows, required this.pageKey});

  final int rows;
  final GlobalKey<HostState> pageKey;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  final Map<int, CustomPopupMenuController> controllers = {};
  int rebuilds = 0;

  /// Exactly what `_restoreFromStore` does to the map, minus the data work.
  void clearControllers() {
    setState(() {
      controllers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    rebuilds++;
    return ListView.builder(
      itemCount: widget.rows,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) => SizedBox(
        height: 60,
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            TranslationDotsButton(
              key: ValueKey('dots_$i'),
              controller: controllers.putIfAbsent(
                  i, () => CustomPopupMenuController()),
              options: null,
              onSelectTranslation: (_) {},
              onLoadTranslations: () async => null,
              onOpen: () {},
              onClose: () {
                // The screen's handler: hide the controller the map holds now.
                controllers[i]?.hideMenu();
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openDots(WidgetTester tester, int row) async {
  await tester.tap(find.byKey(ValueKey('dots_$row')));
  await tester.pumpAndSettle();
}

bool menuVisible() => find
    .byWidgetPredicate((w) => w is Material && w.color == Colors.black87)
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('row 0 after a controller-map clear: close icon is dead',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hostKey = GlobalKey<HostState>();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Host(key: hostKey, rows: 6, pageKey: hostKey))),
    );
    await tester.pumpAndSettle();

    // Row 0 exists first, so `putIfAbsent` already created a controller for it.
    final staleForRow0 = hostKey.currentState!.controllers[0]!;
    debugPrint('row0 controller (before clear) = ${staleForRow0.hashCode}');

    // Restore/reorder clears the map; the next build makes new controllers.
    hostKey.currentState!.clearControllers();
    await tester.pumpAndSettle();

    final freshRow0 = hostKey.currentState!.controllers[0]!;
    final freshRow1 = hostKey.currentState!.controllers[1]!;
    debugPrint('row0 controller (after clear)  = ${freshRow0.hashCode}');
    debugPrint('row1 controller (after clear)  = ${freshRow1.hashCode}');
    debugPrint('row0 was replaced = ${!identical(staleForRow0, freshRow0)}');

    await openDots(tester, 0);
    debugPrint('row0 menu visible after open = ${menuVisible()}');

    // Tap the popup's own close icon -> onClose -> the map's (new) controller.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    debugPrint('row0 menu visible after close tap = ${menuVisible()}');
    debugPrint('row0 fresh.menuIsShowing = ${freshRow0.menuIsShowing}');
    debugPrint('row0 stale.menuIsShowing = ${staleForRow0.menuIsShowing}');

    // Row 1 is created AFTER the clear, so it should be healthy.
    await openDots(tester, 1);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    debugPrint('row1 menu visible after close tap = ${menuVisible()}');
  });
}
