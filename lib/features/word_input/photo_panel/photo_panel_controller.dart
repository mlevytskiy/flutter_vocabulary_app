import 'package:flutter/foundation.dart';

import 'photo_panel_stops.dart';

/// The photo panel's current stop and its one selected photo (sad §4 "State
/// placement"). Owned by the main screen's `State`; transient, never saved.
class PhotoPanelController extends ChangeNotifier {
  PanelStop _stop = PanelStop.closed;
  String? _selectedId;

  PanelStop get stop => _stop;

  /// The selected photo's source id, or null (spec AC-05).
  String? get selectedId => _selectedId;

  bool get isOpen => _stop != PanelStop.closed;

  /// Moves to [stop]; closed clears the selection (spec AC-05).
  void setStop(PanelStop stop) {
    final selected = stop == PanelStop.closed ? null : _selectedId;
    if (stop == _stop && selected == _selectedId) return;
    _stop = stop;
    _selectedId = selected;
    notifyListeners();
  }

  void close() => setStop(PanelStop.closed);

  /// Back: full-open → half-open → closed (spec AC-10).
  void stepBack() {
    if (_stop == PanelStop.closed) return;
    setStop(PanelStop.values[_stop.index - 1]);
  }

  /// The same photo again clears the selection; another photo moves it.
  void select(String id) {
    _selectedId = _selectedId == id ? null : id;
    notifyListeners();
  }

  /// Keeps the state in step with the photos with words (spec AC-15): a
  /// vanished selected photo is unselected, and with none left the panel closes.
  void retain(List<String> ids) {
    if (ids.isEmpty) {
      close();
      return;
    }
    if (_selectedId != null && !ids.contains(_selectedId)) {
      _selectedId = null;
      notifyListeners();
    }
  }
}
