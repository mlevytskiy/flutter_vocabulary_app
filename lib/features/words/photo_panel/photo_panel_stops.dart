/// The photo panel's three stops on its one openness value, 0 → 1 (ADR-0001).
enum PanelStop {
  closed(0),
  halfOpen(0.5),
  fullOpen(1);

  const PanelStop(this.openness);

  final double openness;
}

/// A release faster than this, in openness per second, is a flick: it moves
/// one stop past the stop the drag started from (spec AC-08).
const double kPanelFlickVelocity = 1.5;

/// Where a released drag settles (spec AC-08). Positive [velocity] opens
/// (a drag to the left), negative closes. Pure: no widgets, no state.
///
/// - A slow release settles at the nearest stop.
/// - A flick moves exactly one stop beyond [start] in its direction, never two.
/// - Any drag to the left from closed opens at least half-open (AC-03).
PanelStop settle(PanelStop start, double openness, double velocity) {
  if (velocity.abs() >= kPanelFlickVelocity) {
    final next = start.index + (velocity > 0 ? 1 : -1);
    return PanelStop.values[next.clamp(0, PanelStop.values.length - 1)];
  }
  var nearest = PanelStop.closed;
  for (final stop in PanelStop.values) {
    if ((stop.openness - openness).abs() < (nearest.openness - openness).abs()) {
      nearest = stop;
    }
  }
  if (start == PanelStop.closed && openness > 0 && nearest == PanelStop.closed) {
    return PanelStop.halfOpen;
  }
  return nearest;
}
