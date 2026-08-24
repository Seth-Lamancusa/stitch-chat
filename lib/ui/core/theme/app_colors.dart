import 'package:flutter/material.dart';

/// Brand/layout tokens that fall outside Material 3's [ColorScheme] roles.
/// Anything expressible as a colorScheme/surface/outline role (backgrounds,
/// borders, text emphasis) should use that instead. This extension exists
/// for two kinds of things ColorScheme can't express:
///
///  - the stitch-edge green family, ported from stitch-frontend's
///    `SiblingNavigator.vue`/`LinkSwitcher.vue`/`AdaptiveMarker.vue`: a fixed
///    brand accent rather than something derived from the seed color.
///  - [appBarSurface]/[columnHeaderSurface]: chrome (the top app bar, each
///    column's header) is meant to read as a distinct, fixed bar rather than
///    something that shifts with Material's elevation/scroll tinting.
///    [appBarSurface] defaults to roughly the same light tone as the
///    unselected [columnHeaderSurface] so the app bar reads as part of the
///    same chrome family as column headers.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.stitchGreen,
    required this.stitchGreenBorderIdle,
    required this.stitchGreenBorderHover,
    required this.stitchGreenFillIdle,
    required this.stitchGreenFillHover,
    required this.appBarSurface,
    required this.columnHeaderSurface,
    required this.columnHeaderSurfaceSelected,
  });

  final Color stitchGreen;
  final Color stitchGreenBorderIdle;
  final Color stitchGreenBorderHover;
  final Color stitchGreenFillIdle;
  final Color stitchGreenFillHover;
  final Color appBarSurface;
  final Color columnHeaderSurface;
  final Color columnHeaderSurfaceSelected;

  static const _stitchGreen = Color(0xFF2C8F40); // rgba()
  static const _stitchGreenBorderIdle = Color(0x994CAF50); // rgba(76,175,80,0.6)
  static const _stitchGreenBorderHover = Color(0xD94CAF50); // rgba(76,175,80,0.85)
  static const _stitchGreenFillIdle = Color(0x594CAF50); // rgba(76,175,80,0.35)
  static const _stitchGreenFillHover = Color(0x8C4CAF50); // rgba(76,175,80,0.55)

  static const light = AppColors(
    stitchGreen: _stitchGreen,
    stitchGreenBorderIdle: _stitchGreenBorderIdle,
    stitchGreenBorderHover: _stitchGreenBorderHover,
    stitchGreenFillIdle: _stitchGreenFillIdle,
    stitchGreenFillHover: _stitchGreenFillHover,
    appBarSurface: Color(0xFFF9F5F1), // matches unselected column header
    columnHeaderSurface: Color(0xFFF9F5F1), // very light — almost same as canvas
    columnHeaderSurfaceSelected: Color(0xFFE8DDD2), // slightly darker for selection
  );

  static const dark = AppColors(
    stitchGreen: _stitchGreen,
    stitchGreenBorderIdle: _stitchGreenBorderIdle,
    stitchGreenBorderHover: _stitchGreenBorderHover,
    stitchGreenFillIdle: _stitchGreenFillIdle,
    stitchGreenFillHover: _stitchGreenFillHover,
    appBarSurface: Color(0xFF151210), // matches unselected column header
    columnHeaderSurface: Color(0xFF151210), // very close to surface
    columnHeaderSurfaceSelected: Color(0xFF201B16), // slightly darker for selection
  );

  @override
  AppColors copyWith({
    Color? stitchGreen,
    Color? stitchGreenBorderIdle,
    Color? stitchGreenBorderHover,
    Color? stitchGreenFillIdle,
    Color? stitchGreenFillHover,
    Color? appBarSurface,
    Color? columnHeaderSurface,
    Color? columnHeaderSurfaceSelected,
  }) {
    return AppColors(
      stitchGreen: stitchGreen ?? this.stitchGreen,
      stitchGreenBorderIdle: stitchGreenBorderIdle ?? this.stitchGreenBorderIdle,
      stitchGreenBorderHover: stitchGreenBorderHover ?? this.stitchGreenBorderHover,
      stitchGreenFillIdle: stitchGreenFillIdle ?? this.stitchGreenFillIdle,
      stitchGreenFillHover: stitchGreenFillHover ?? this.stitchGreenFillHover,
      appBarSurface: appBarSurface ?? this.appBarSurface,
      columnHeaderSurface: columnHeaderSurface ?? this.columnHeaderSurface,
      columnHeaderSurfaceSelected: columnHeaderSurfaceSelected ?? this.columnHeaderSurfaceSelected,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      stitchGreen: Color.lerp(stitchGreen, other.stitchGreen, t)!,
      stitchGreenBorderIdle: Color.lerp(stitchGreenBorderIdle, other.stitchGreenBorderIdle, t)!,
      stitchGreenBorderHover: Color.lerp(stitchGreenBorderHover, other.stitchGreenBorderHover, t)!,
      stitchGreenFillIdle: Color.lerp(stitchGreenFillIdle, other.stitchGreenFillIdle, t)!,
      stitchGreenFillHover: Color.lerp(stitchGreenFillHover, other.stitchGreenFillHover, t)!,
      appBarSurface: Color.lerp(appBarSurface, other.appBarSurface, t)!,
      columnHeaderSurface: Color.lerp(columnHeaderSurface, other.columnHeaderSurface, t)!,
      columnHeaderSurfaceSelected: Color.lerp(columnHeaderSurfaceSelected, other.columnHeaderSurfaceSelected, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// Shorthand for `Theme.of(this).extension<AppColors>()!`. Only ever
  /// throws if [AppTheme]'s themes stop registering the extension.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
