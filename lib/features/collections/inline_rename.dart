import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/collection_name.dart';
import '../../core/services/collection_level.dart';
import '../../core/theme/app_theme.dart';
import 'collection_icon.dart';
import 'collections_view.dart';
import 'name_dialog.dart';

/// The name field of a tile being renamed in place (collection inline
/// rename, owner 2026-11-03): the name's own style, centred, at most two
/// lines, with only a thin underline. Enter or Done saves, Esc cancels.
class InlineNameField extends StatelessWidget {
  const InlineNameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
    required this.onChanged,
    required this.onTapOutside,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onChanged;

  /// A tap anywhere but the field and its selection toolbar.
  final VoidCallback onTapOutside;
  final String? errorText;

  static const fieldKey = Key('inline-name-field');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    UnderlineInputBorder line(Color c) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
        const SingleActivator(LogicalKeyboardKey.enter): onSubmit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit,
      },
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        // In place of the default unfocus: the screen saves.
        onTapOutside: (_) => onTapOutside(),
        textAlign: TextAlign.center,
        style: CollectionIcon.nameStyle,
        minLines: 1,
        maxLines: 2,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        // One line, as in the name dialog (SCR-02).
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp('[\r\n]'))],
        onSubmitted: (_) => onSubmit(),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          contentPadding: const EdgeInsets.only(bottom: 2),
          border: line(AppDecor.of(context).muted),
          enabledBorder: line(AppDecor.of(context).muted),
          focusedBorder: line(scheme.primary),
          errorText: errorText,
          errorMaxLines: 3,
          // A little smaller than the default, to fit the 160-high cell.
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

/// In-place rename on the Collections grid: the edited item's id, its field's
/// controller and focus, kept in the screen's State (rule 2). A long press
/// released without moving, begun on the name, starts it ([startRename]);
/// a tap outside, Done/Enter, the keyboard closing, the app going to the
/// background or the screen going away saves it; Esc cancels. One item at a
/// time, keyed by id.
mixin InlineRename<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, WidgetsBindingObserver {
  final renameController = TextEditingController();
  final renameFocus = FocusNode(debugLabel: 'inline rename');

  /// Around the edited tile, to keep it above the keyboard.
  final renameTileKey = GlobalKey();

  /// The item being renamed; null when none is.
  String? editingId;
  String _original = '';
  String? _error;

  /// Saved names until the level's stream shows them.
  final _saved = <String, String>{};

  /// The item whose name the last pointer went down on.
  String? _pressedName;
  double _inset = 0;

  /// Room the round buttons take at the bottom of the grid.
  static const _buttonRoom = 96.0;

  /// Writes the name; the screen goes through its notifier.
  Future<FilingResult> renameItem(String id, String name);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    renameFocus.addListener(_focusChanged);
  }

  @override
  void deactivate() {
    // Popped or replaced: the name typed so far is kept.
    commitRename(quiet: true);
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    renameFocus.removeListener(_focusChanged);
    renameFocus.dispose();
    renameController.dispose();
    super.dispose();
  }

  /// [items] with the names just saved, until the store's stream has them.
  List<CollectionItemView>? withSavedNames(List<CollectionItemView>? items) {
    if (items == null || _saved.isEmpty) return items;
    _saved.removeWhere(
        (id, name) => items.any((i) => i.id == id && i.name == name));
    return [
      for (final i in items)
        _saved[i.id] == null
            ? i
            : CollectionItemView(
                id: i.id,
                isFolder: i.isFolder,
                name: _saved[i.id]!,
                wordCount: i.wordCount,
                isCurrent: i.isCurrent,
                badges: i.badges,
              ),
    ];
  }

  /// After a build: the edited item is gone from [shown] (search, filter,
  /// another folder, deleted): save and close.
  void closeRenameIfGone(List<CollectionItemView>? shown) {
    final id = editingId;
    if (id == null) return;
    if (shown != null && shown.any((i) => i.id == id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && editingId == id) commitRename();
    });
  }

  /// `CollectionsGrid.onPress`.
  void renamePress(CollectionItemView item, bool onName) =>
      _pressedName = onName ? item.id : null;

  /// `DraggableCollectionIcon.onLongPressNoMove`: renames when the press
  /// began on the name.
  void renameLongPressNoMove(CollectionItemView item) {
    if (_pressedName == item.id) startRename(item);
    _pressedName = null;
  }

  void startRename(CollectionItemView item) {
    if (editingId == item.id) return;
    commitRename();
    if (editingId != null) return; // the other name is not valid yet
    setState(() {
      editingId = item.id;
      _original = item.name;
      _error = null;
      renameController.value = TextEditingValue(
        text: item.name,
        selection: TextSelection(baseOffset: 0, extentOffset: item.name.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || editingId != item.id) return;
      renameFocus.requestFocus();
      renameController.selection = TextSelection(
          baseOffset: 0, extentOffset: renameController.text.length);
      _reveal();
    });
  }

  /// The name field shows the rules' message.
  bool get renameShowsError => _error != null;

  /// The name field for [item], or null when it is not the one edited.
  Widget? renameFieldFor(CollectionItemView item) {
    if (item.id != editingId) return null;
    return InlineNameField(
      controller: renameController,
      focusNode: renameFocus,
      errorText: _error,
      onSubmit: commitRename,
      onCancel: cancelRename,
      onTapOutside: commitRename,
      onChanged: () {
        if (_error != null) setState(() => _error = null);
      },
    );
  }

  /// Saves the typed name: trimmed; empty or unchanged writes nothing. A name
  /// the rules refuse keeps the field open with the dialog's message, unless
  /// [quiet] (the screen is going away), when it is dropped.
  void commitRename({bool quiet = false}) {
    final id = editingId;
    if (id == null) return;
    final name = renameController.text.trim();
    if (name.isEmpty || name == _original) {
      _close(quiet);
      return;
    }
    if (collectionNameProblem(name) != null) {
      if (quiet) {
        _close(quiet);
      } else {
        setState(() => _error = nameProblemMessage);
      }
      return;
    }
    _saved[id] = name;
    _close(quiet);
    renameItem(id, name).then((result) {
      if (result != FilingResult.done && mounted) {
        setState(() => _saved.remove(id));
      }
    });
  }

  void cancelRename() => _close(false);

  void _close(bool quiet) {
    editingId = null;
    _error = null;
    if (quiet) return;
    if (renameFocus.hasFocus) renameFocus.unfocus();
    setState(() {});
  }

  void _focusChanged() {
    if (!renameFocus.hasFocus && editingId != null && _error == null) {
      commitRename();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = View.maybeOf(context);
    if (view == null) return;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final was = _inset;
    _inset = inset;
    if (editingId == null || inset == was) return;
    // The keyboard closed (Android Back, the system hiding it): save.
    if (inset == 0) {
      commitRename();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      commitRename();
    }
  }

  /// Scrolls the edited tile, and the round buttons' room below it, into the
  /// part of the grid the keyboard leaves.
  void _reveal() {
    final box = renameTileKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    box.showOnScreen(
        rect: Offset.zero &
            Size(box.size.width, box.size.height + _buttonRoom));
  }
}
