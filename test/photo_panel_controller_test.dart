import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

/// side-bar-for-main-screen T1: the panel's stop and its one selected photo
/// (spec AC-05, AC-15). Nothing is saved.
void main() {
  late PhotoPanelController controller;
  late int notified;

  setUp(() {
    controller = PhotoPanelController();
    notified = 0;
    controller.addListener(() => notified++);
  });
  tearDown(() => controller.dispose());

  test('starts closed with nothing selected', () {
    expect(controller.stop, PanelStop.closed);
    expect(controller.selectedId, isNull);
    expect(controller.isOpen, isFalse);
  });

  test('select toggles: same photo again clears, another photo moves', () {
    controller.select('a');
    expect(controller.selectedId, 'a');
    controller.select('b');
    expect(controller.selectedId, 'b');
    controller.select('b');
    expect(controller.selectedId, isNull);
    expect(notified, 3);
  });

  test('setStop notifies once per change and not for the same stop', () {
    controller.setStop(PanelStop.halfOpen);
    controller.setStop(PanelStop.halfOpen);
    expect(controller.stop, PanelStop.halfOpen);
    expect(controller.isOpen, isTrue);
    expect(notified, 1);
  });

  test('closing clears the selection, with one notification', () {
    controller.setStop(PanelStop.halfOpen);
    controller.select('a');
    notified = 0;
    controller.close();
    expect(controller.stop, PanelStop.closed);
    expect(controller.selectedId, isNull);
    expect(notified, 1);
  });

  test('setStop(closed) clears the selection too', () {
    controller.setStop(PanelStop.halfOpen);
    controller.select('a');
    controller.setStop(PanelStop.closed);
    expect(controller.selectedId, isNull);
  });

  test('stepBack: full-open → half-open keeps the selection, half-open → closed clears it', () {
    controller.setStop(PanelStop.halfOpen);
    controller.select('a');
    controller.setStop(PanelStop.fullOpen);
    controller.stepBack();
    expect(controller.stop, PanelStop.halfOpen);
    expect(controller.selectedId, 'a');
    controller.stepBack();
    expect(controller.stop, PanelStop.closed);
    expect(controller.selectedId, isNull);
    notified = 0;
    controller.stepBack();
    expect(controller.stop, PanelStop.closed);
    expect(notified, 0);
  });

  test('retain clears a selected photo that is no longer listed', () {
    controller.select('a');
    notified = 0;
    controller.retain(['a', 'b']);
    expect(controller.selectedId, 'a');
    expect(notified, 0);
    controller.retain(['b']);
    expect(controller.selectedId, isNull);
    expect(notified, 1);
  });

  test('retain with no photos left closes the panel', () {
    controller.setStop(PanelStop.fullOpen);
    controller.select('a');
    controller.retain(const []);
    expect(controller.stop, PanelStop.closed);
    expect(controller.selectedId, isNull);
  });
}
