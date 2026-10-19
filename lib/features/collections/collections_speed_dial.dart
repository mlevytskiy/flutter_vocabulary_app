import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../core/theme/app_theme.dart';

/// The Collections screen's plus button, styled like the main screen's
/// `WordsSpeedDial`: New folder and New collection.
class CollectionsSpeedDial extends StatelessWidget {
  const CollectionsSpeedDial({
    super.key,
    required this.onNewFolder,
    required this.onNewCollection,
  });

  final VoidCallback onNewFolder;
  final VoidCallback onNewCollection;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: decor.fab,
      foregroundColor: decor.onFab,
      activeBackgroundColor: decor.fabActive,
      activeForegroundColor: decor.onFab,
      visible: true,
      closeManually: false,
      curve: Curves.bounceIn,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      elevation: 8.0,
      shape: const CircleBorder(),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.create_new_folder_outlined),
          label: 'New folder',
          backgroundColor: decor.dialFolder,
          foregroundColor: decor.onDial,
          onTap: onNewFolder,
        ),
        SpeedDialChild(
          child: const Icon(Icons.library_add_outlined),
          label: 'New collection',
          backgroundColor: decor.dialQuizlet,
          foregroundColor: decor.onDial,
          onTap: onNewCollection,
        ),
      ],
    );
  }
}
