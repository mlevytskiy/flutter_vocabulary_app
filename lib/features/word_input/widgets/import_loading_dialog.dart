import 'package:flutter/material.dart';

/// The loading dialog of a subtitle import (words-from-subtitles SCR-04). It
/// cannot be dismissed by the barrier or back, so the learner cannot switch
/// sessions while the words are being picked (AC-16); the import flow closes
/// it with [closeImportLoadingDialog].
void showImportLoadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Picking words from the subtitles…')),
          ],
        ),
      ),
    ),
  );
}

/// Closes the dialog opened by [showImportLoadingDialog].
void closeImportLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
