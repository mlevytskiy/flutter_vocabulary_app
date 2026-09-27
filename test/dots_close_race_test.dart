import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// Reproduces the device sequence: keyboard up, tap the dots (the app unfocuses
/// -> the keyboard goes away), then let the inset change settle. The popup must
/// survive that.
void main() {
  testWidgets('popup survives the keyboard going away after the tap',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CustomPopupMenuController();
    final focus = FocusNode();
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('English Vocabulary')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < 12; i++)
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: i == 9 ? focus : null,
                          decoration: const InputDecoration(hintText: 'Word'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (i == 9)
                        TranslationDotsButton(
                          controller: controller,
                          options: null,
                          onSelectTranslation: (_) {},
                          onLoadTranslations: () async => null,
                          onOpen: () {
                            opened++;
                            // The app's real handler.
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          onClose: controller.hideMenu,
                        )
                      else
                        const SizedBox(width: 26),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(focus.hasFocus ? find.byType(TextField).at(9) : find.byType(TextField).at(9));
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();

    // Keyboard up (device state when the owner taps the dots).
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    await tester.pumpAndSettle();
    debugPrint('keyboard up, bolts visible (focused) = ${focus.hasFocus}');

    final dots = find.byIcon(Icons.circle_outlined);
    final rect = tester.getRect(dots.last);
    debugPrint('anchor=$rect');

    await tester.tapAt(rect.center);
    debugPrint('right after tap: menuIsShowing=${controller.menuIsShowing} opened=$opened');

    // The keyboard dismissing animates the inset back to zero in steps.
    for (final inset in <double>[300, 240, 180, 120, 60, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset * 3);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();

    debugPrint('AFTER keyboard dismissal: menuIsShowing=${controller.menuIsShowing}');
    final panels = find.byWidgetPredicate(
      (w) => w is Material && w.color == Colors.black87,
    );
    debugPrint('panels on screen = ${panels.evaluate().length}');
    debugPrint('close icon present = ${find.byIcon(Icons.close).evaluate().isNotEmpty}');
  });
}
