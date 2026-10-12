import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

/// side-bar-for-main-screen T1: a released drag settles at the nearest stop,
/// a flick moves one stop past the start stop and never two, and any drag to
/// the left from closed opens at least half-open (spec AC-08, AC-03).
void main() {
  const slow = 0.0;
  const fastOpen = kPanelFlickVelocity * 2; // toward full-open (leftward)
  const fastClose = -kPanelFlickVelocity * 2; // toward closed (rightward)

  test('the stops sit at 0, 0.5 and 1', () {
    expect(PanelStop.closed.openness, 0);
    expect(PanelStop.halfOpen.openness, 0.5);
    expect(PanelStop.fullOpen.openness, 1);
  });

  group('slow release settles at the nearest stop', () {
    final cases = <(PanelStop, double, PanelStop)>[
      (PanelStop.halfOpen, 0.0, PanelStop.closed),
      (PanelStop.halfOpen, 0.2, PanelStop.closed),
      (PanelStop.halfOpen, 0.3, PanelStop.halfOpen),
      (PanelStop.halfOpen, 0.7, PanelStop.halfOpen),
      (PanelStop.halfOpen, 0.8, PanelStop.fullOpen),
      (PanelStop.fullOpen, 0.9, PanelStop.fullOpen),
      (PanelStop.fullOpen, 0.6, PanelStop.halfOpen),
      (PanelStop.fullOpen, 0.1, PanelStop.closed),
      (PanelStop.closed, 0.6, PanelStop.halfOpen),
      (PanelStop.closed, 0.9, PanelStop.fullOpen),
    ];
    for (final (start, openness, expected) in cases) {
      test('$start released at $openness → $expected', () {
        expect(settle(start, openness, slow), expected);
      });
    }
  });

  group('any leftward drag from closed opens at least half-open', () {
    for (final openness in [0.01, 0.1, 0.24]) {
      test('closed released at $openness → halfOpen', () {
        expect(settle(PanelStop.closed, openness, slow), PanelStop.halfOpen);
      });
    }
    test('no movement from closed stays closed', () {
      expect(settle(PanelStop.closed, 0, slow), PanelStop.closed);
    });
    test('a flick back to the right from closed stays closed', () {
      expect(settle(PanelStop.closed, 0.05, fastClose), PanelStop.closed);
    });
  });

  group('a flick moves exactly one stop past the start stop', () {
    final cases = <(PanelStop, double, double, PanelStop)>[
      (PanelStop.closed, 0.1, fastOpen, PanelStop.halfOpen),
      (PanelStop.closed, 0.95, fastOpen, PanelStop.halfOpen), // never skips
      (PanelStop.halfOpen, 0.55, fastOpen, PanelStop.fullOpen),
      (PanelStop.halfOpen, 0.45, fastClose, PanelStop.closed),
      (PanelStop.fullOpen, 0.9, fastClose, PanelStop.halfOpen),
      (PanelStop.fullOpen, 0.05, fastClose, PanelStop.halfOpen), // never skips
      (PanelStop.fullOpen, 1.0, fastOpen, PanelStop.fullOpen), // no stop beyond
      (PanelStop.halfOpen, 0.2, fastOpen, PanelStop.fullOpen),
    ];
    for (final (start, openness, velocity, expected) in cases) {
      test('$start flicked ${velocity > 0 ? 'open' : 'closed'} at $openness → $expected', () {
        expect(settle(start, openness, velocity), expected);
      });
    }
  });

  test('a velocity just under the flick threshold counts as slow', () {
    expect(settle(PanelStop.halfOpen, 0.6, kPanelFlickVelocity * 0.99), PanelStop.halfOpen);
    expect(settle(PanelStop.halfOpen, 0.6, kPanelFlickVelocity), PanelStop.fullOpen);
  });
}
