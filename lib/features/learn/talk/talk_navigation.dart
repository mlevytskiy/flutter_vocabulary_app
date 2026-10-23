import 'package:flutter/widgets.dart';

/// Opens the results of a finished talk (learn-redesign SCR-04). Until the
/// results route is wired in, the talk screen just closes.
void openSessionResults(BuildContext context, String? collectionId) {
  Navigator.of(context).pop();
}
