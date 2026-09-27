import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// Mirrors the real screen: one row per word pair, and -- critically -- one
/// `CustomPopupMenuController` *per row*, exactly as `_popupControllers` does.
///
/// Sharing a single controller across rows is not a valid stand-in: the popup
/// package keeps the menu's hit rectangle in one top-level global that every
/// open menu writes to during layout, so several menus open at once and the
/// last one to lay out owns the rectangle. That is what a shared controller
/// produces, and it breaks the close button in a way the app never does.
const rowCount = 14;
const focusedRow = 8;

class WordRow extends StatelessWidget {
  const WordRow({
    super.key,
    required this.index,
    required this.controller,
    required this.onOpen,
    required this.onClose,
    required this.focusNode,
  });

  final int index;
  final CustomPopupMenuController controller;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                focusNode: focusNode,
                decoration: const InputDecoration(hintText: 'Word'),
              ),
            ),
            const SizedBox(width: 4),
            TranslationDotsButton(
              key: ValueKey('dots_$index'),
              controller: controller,
              options: null,
              onSelectTranslation: (_) {},
              onLoadTranslations: () async => null,
              onOpen: onOpen,
              onClose: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('tapping the close icon hides the popup', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controllers =
        List.generate(rowCount, (_) => CustomPopupMenuController());
    final focusNodes = List.generate(rowCount, (_) => FocusNode());
    addTearDown(() {
      for (final n in focusNodes) {
        n.dispose();
      }
    });

    var openedIndex = -1;
    var closedIndex = -1;
    var unfocused = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('English Vocabulary')),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rowCount,
            itemBuilder: (context, i) => WordRow(
              index: i,
              controller: controllers[i],
              focusNode: focusNodes[i],
              // Both handlers mirror word_input_screen.dart.
              onOpen: () {
                openedIndex = i;
                unfocused++;
                FocusManager.instance.primaryFocus?.unfocus();
              },
              onClose: () {
                closedIndex = i;
                controllers[i].hideMenu();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(TextField).at(focusedRow));
    await tester.pumpAndSettle();
    focusNodes[focusedRow].requestFocus();
    await tester.pumpAndSettle();
    expect(focusNodes[focusedRow].hasFocus, isTrue, reason: 'row 8 focused');

    // Keyboard up: the state the owner taps the dots in.
    const keyboard = 336.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final usableBottom = size.height - keyboard;

    // The lowest dots button still above the keyboard.
    var chosen = -1;
    var best = -1.0;
    for (var i = 0; i < rowCount; i++) {
      final finder = find.byKey(ValueKey('dots_$i'));
      if (finder.evaluate().isEmpty) continue;
      final r = tester.getRect(finder);
      if (r.center.dy > 0 && r.center.dy < usableBottom && r.center.dy > best) {
        best = r.center.dy;
        chosen = i;
      }
    }
    expect(chosen, isNonNegative, reason: 'a dots button must be tappable');
    final anchorRect = tester.getRect(find.byKey(ValueKey('dots_$chosen')));
    debugPrint('chosen row=$chosen anchor=$anchorRect keyboard=$keyboard');

    await tester.tapAt(anchorRect.center);
    await tester.pumpAndSettle();

    // The device drops the keyboard as the popup opens.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    final panels = find.byWidgetPredicate(
      (w) => w is Material && w.color == Colors.black87,
    );
    debugPrint('after open: opened=$openedIndex unfocused=$unfocused '
        'menuIsShowing=${controllers[chosen].menuIsShowing} '
        'panels=${panels.evaluate().length}');

    expect(openedIndex, chosen, reason: 'the tapped row is the one that opens');
    expect(controllers[chosen].menuIsShowing, isTrue, reason: 'popup must open');
    expect(panels.evaluate().length, 1,
        reason: 'exactly one menu: one controller per row');

    final close = find.descendant(
      of: panels.first,
      matching: find.byIcon(Icons.close),
    );
    final closeRect = tester.getRect(close.first);
    debugPrint('close rect=$closeRect viewport=$size keyboardGone=true');

    await tester.tap(close.first);
    await tester.pumpAndSettle();

    debugPrint('after close: closed=$closedIndex '
        'menuIsShowing=${controllers[chosen].menuIsShowing}');

    expect(closedIndex, chosen,
        reason: 'the screen-owned close handler must fire for that row');
    expect(controllers[chosen].menuIsShowing, isFalse,
        reason: 'close must hide the menu');
    expect(find.byIcon(Icons.close), findsNothing,
        reason: 'the popup must be gone after its close icon is tapped');
  });
}
