import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Single source of truth for both brightness variants. Widgets should never
/// construct a [ThemeData] or reach for a hardcoded [Colors] value directly —
/// pull backgrounds/borders/text emphasis from `Theme.of(context).colorScheme`
/// (Material 3 roles already adapt across light/dark for free) and brand-only
/// colors from `context.appColors`.
class AppTheme {
  AppTheme._();

  static const _seedColor = Colors.deepPurple;

  // Material's algorithmic neutrals lean cool violet-grey in both
  // brightnesses (light surface comes out ~#FEF7FF, dark ~#151217 — the
  // latter so close to black that AppColors.headerSurface has no visible
  // room to sit below it). Overriding just the neutral surface/outline roles
  // keeps the seed-derived brand colors (primary, secondary, tertiary,
  // error) untouched while giving both themes a warm cast — cream instead of
  // stock white/grey in light mode, warm charcoal instead of near-black in
  // dark mode — and leaving headroom for the header to read as a distinct,
  // always-darker bar in both.
  static final _neutralsByBrightness = {
    Brightness.light: const {
      'surfaceDim': Color(0xFFECCFAF),
      'surface': Color(0xFFFAF6EC),
      'surfaceBright': Color(0xFFFFFCF5),
      'surfaceContainerLowest': Color(0xFFFFFDF7),
      'surfaceContainerLow': Color(0xFFF5EFE0),
      'surfaceContainer': Color(0xFFF0E8D5),
      'surfaceContainerHigh': Color(0xFFEAE0C8),
      'surfaceContainerHighest': Color(0xFFE2D5B8),
      'onSurface': Color(0xFF2A2620),
      'onSurfaceVariant': Color(0xFF5C5647),
      'outline': Color(0xFFB4AB95),
      'outlineVariant': Color(0xFFDCD2B9),
    },
    Brightness.dark: const {
      'surfaceDim': Color(0xFF1C1B18),
      'surface': Color(0xFF242220),
      'surfaceBright': Color(0xFF3A3733),
      'surfaceContainerLowest': Color(0xFF171615),
      'surfaceContainerLow': Color(0xFF201E1B),
      'surfaceContainer': Color(0xFF262420),
      'surfaceContainerHigh': Color(0xFF302D28),
      'surfaceContainerHighest': Color(0xFF3A3631),
      'onSurface': Color(0xFFECE6DC),
      'onSurfaceVariant': Color(0xFFC7C0B2),
      'outline': Color(0xFF686258),
      'outlineVariant': Color(0xFF45413A),
    },
  };

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors appColors) {
    final n = _neutralsByBrightness[brightness]!;
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness).copyWith(
      surfaceDim: n['surfaceDim'],
      surface: n['surface'],
      surfaceBright: n['surfaceBright'],
      surfaceContainerLowest: n['surfaceContainerLowest'],
      surfaceContainerLow: n['surfaceContainerLow'],
      surfaceContainer: n['surfaceContainer'],
      surfaceContainerHigh: n['surfaceContainerHigh'],
      surfaceContainerHighest: n['surfaceContainerHighest'],
      onSurface: n['onSurface'],
      onSurfaceVariant: n['onSurfaceVariant'],
      outline: n['outline'],
      outlineVariant: n['outlineVariant'],
    );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.latoTextTheme(base.textTheme),
      extensions: [appColors],
    );
  }
}
