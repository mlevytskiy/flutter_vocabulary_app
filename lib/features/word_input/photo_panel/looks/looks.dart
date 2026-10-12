import '../../../../core/providers.dart';
import 'look_a.dart';
import 'look_b.dart';
import 'photo_panel_look.dart';

/// The look for each design variant (ADR-0003). Until look C exists (T17)
/// it shows look A. At the pick (T20) only the kept look stays.
PhotoPanelLook lookFor(PhotoPanelVariant variant) => switch (variant) {
      PhotoPanelVariant.a => const LookA(),
      PhotoPanelVariant.b => const LookB(),
      PhotoPanelVariant.c => const LookA(),
    };
