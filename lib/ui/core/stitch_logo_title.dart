import 'package:flutter/material.dart';

/// Stitch logo on the oval backdrop used in the app bar title slot.
class StitchLogoTitle extends StatelessWidget {
  const StitchLogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    // Native pixel dimensions of assets/images/stitch_logo.png.
    const logoAspectRatio = 917 / 516;
    const logoHeight = 28.0;
    const logoWidth = logoHeight * logoAspectRatio;
    // Oval backdrop sized proportionally to the rendered logo so it
    // hugs the artwork instead of forming a circle.
    const glowWidth = logoWidth * 2;
    const glowHeight = logoHeight * 1.6;
    const ringThickness = 1.0;
    const earthBrown = Color(0xFF4A3222);
    const foliageGreen = Color(0xFF1F3D2B);

    return SizedBox(
      width: glowWidth,
      height: glowHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // BoxShape.circle inscribes a circle bounded by the
          // shorter side of the box, so it wouldn't fill a
          // non-square box. ClipOval instead fits an ellipse to
          // the full bounding box, giving a true oval. Two nested
          // ClipOvals (green, then brown inset by ringThickness)
          // produce a brown fill with a thin green ring.
          ClipOval(
            child: Container(
              width: glowWidth,
              height: glowHeight,
              color: foliageGreen,
            ),
          ),
          ClipOval(
            child: Container(
              width: glowWidth - ringThickness * 2,
              height: glowHeight - ringThickness * 2,
              color: earthBrown,
            ),
          ),
          Image.asset(
            'assets/images/stitch_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
