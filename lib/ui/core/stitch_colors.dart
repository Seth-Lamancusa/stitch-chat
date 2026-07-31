import 'package:flutter/material.dart';

/// Shared color tokens for the stitch-edge visual language, ported from
/// stitch-frontend's `main` branch (`SiblingNavigator.vue`/`LinkSwitcher.vue`/
/// `AdaptiveMarker.vue`, all converging on the same green family). Anything
/// that represents a stitch (as opposed to reply) edge in the UI uses these,
/// so the "this crossed into a different tree" cue stays consistent across
/// widgets.
class StitchColors {
  StitchColors._();

  static const Color stitchGreen = Color(0xFF4CAF50);
  static const Color stitchGreenBorderIdle = Color(0x994CAF50); // rgba(76,175,80,0.6)
  static const Color stitchGreenBorderHover = Color(0xD94CAF50); // rgba(76,175,80,0.85)
  static const Color stitchGreenFillIdle = Color(0x594CAF50); // rgba(76,175,80,0.35)
  static const Color stitchGreenFillHover = Color(0x8C4CAF50); // rgba(76,175,80,0.55)

  static const Color surfaceDark = Color(0xFF2A2A2A);
  static const Color surfaceContainerDark = Color(0xFF1E1E1E);
  static const Color borderDark = Color(0xFF444444);
}
