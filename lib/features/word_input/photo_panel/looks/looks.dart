import '../../../../core/providers.dart';
import 'look_a.dart';
import 'photo_panel_look.dart';

/// The look for each design variant (ADR-0003). Until looks B and C exist
/// (T16, T17) they show look A. At the pick (T20) only the kept look stays.
PhotoPanelLook lookFor(PhotoPanelVariant variant) => switch (variant) {
      PhotoPanelVariant.a => const LookA(),
      PhotoPanelVariant.b => const LookA(),
      PhotoPanelVariant.c => const LookA(),
    };
