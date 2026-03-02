import 'package:flutter/material.dart';

class DesignTokens {
  // ── Static dark-mode constants (legacy, kept for compatibility) ──
  static const Color baseDark        = Color(0xFF0A0A0A);
  static const Color surfaceGlass    = Color(0xFF1A1A1A);
  static const Color accentGold      = Color(0xFFC9A24D);
  static const Color textLight       = Color(0xFFF5F7FA);
  static const Color textSecondary   = Color(0xFF888888);

  // ── Light-mode equivalents ────────────────────────────────────────
  static const Color baseLight        = Color(0xFFF2F4F7);
  static const Color surfaceGlassLight = Color(0xFFFFFFFF);
  static const Color textDark         = Color(0xFF0D1117);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // ── Theme-aware helpers ───────────────────────────────────────────
  static bool _isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color background(BuildContext ctx) =>
      _isDark(ctx) ? baseDark : baseLight;

  static Color surface(BuildContext ctx) =>
      _isDark(ctx) ? surfaceGlass : surfaceGlassLight;

  static Color primaryText(BuildContext ctx) =>
      _isDark(ctx) ? textLight : textDark;

  static Color secondaryText(BuildContext ctx) =>
      _isDark(ctx) ? textSecondary : textSecondaryLight;

  static Color border(BuildContext ctx) =>
      _isDark(ctx)
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.09);

  static Color tile(BuildContext ctx, {bool hovered = false}) =>
      _isDark(ctx)
          ? Colors.white.withOpacity(hovered ? 0.06 : 0.0)
          : Colors.black.withOpacity(hovered ? 0.04 : 0.0);

  static Color divider(BuildContext ctx) =>
      _isDark(ctx)
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.07);

  static Color onlineDot = const Color(0xFF4CAF50);

  // ── Typography (theme-aware) ─────────────────────────────────────
  static TextStyle headingLCtx(BuildContext ctx) => TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700,
    color: primaryText(ctx), height: 1.2,
  );
  static TextStyle headingMCtx(BuildContext ctx) => TextStyle(
    fontSize: 24, fontWeight: FontWeight.w600,
    color: primaryText(ctx), height: 1.3,
  );
  static TextStyle headingSCtx(BuildContext ctx) => TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: primaryText(ctx), height: 1.3,
  );
  static TextStyle bodyLCtx(BuildContext ctx) => TextStyle(
    fontSize: 16, color: primaryText(ctx), height: 1.5,
  );
  static TextStyle bodyMCtx(BuildContext ctx) => TextStyle(
    fontSize: 14, color: secondaryText(ctx), height: 1.4,
  );
  static TextStyle captionCtx(BuildContext ctx) => TextStyle(
    fontSize: 12, color: secondaryText(ctx), height: 1.3,
  );

  // ── Legacy static typography (kept for backward compat) ──────────
  static const TextStyle headingL = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700,
    color: textLight, height: 1.2,
  );
  static const TextStyle headingM = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w600,
    color: textLight, height: 1.3,
  );
  static const TextStyle headingS = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: textLight, height: 1.3,
  );
  static const TextStyle bodyL = TextStyle(
    fontSize: 16, color: textLight, height: 1.5,
  );
  static const TextStyle bodyM = TextStyle(
    fontSize: 14, color: textSecondary, height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, color: textSecondary, height: 1.3,
  );

  // ── Spacing ────────────────────────────────────────────────────────
  static const double spacingXs = 4;
  static const double spacingS  = 8;
  static const double spacingM  = 16;
  static const double spacingL  = 24;
  static const double spacingXl = 32;

  // ── Radius ────────────────────────────────────────────────────────
  static const double radiusS = 12;
  static const double radiusM = 20;
  static const double radiusL = 28;

  // ── Blur ──────────────────────────────────────────────────────────
  static const double blurIntensity = 20;

  // ── Shadows ───────────────────────────────────────────────────────
  static final List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}