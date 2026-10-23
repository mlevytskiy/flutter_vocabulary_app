import 'package:flutter/widgets.dart';

import '../../../router/routes.dart';

/// Opens the results of a finished talk (learn-redesign SCR-04), replacing
/// the talk screen so Back from the results does not return to it.
void openSessionResults(BuildContext context, String? collectionId) {
  SessionResultsRoute(collectionId: collectionId).pushReplacement(context);
}
