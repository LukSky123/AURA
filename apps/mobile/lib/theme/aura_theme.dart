import 'package:flutter/material.dart';

class AuraColors {
  static const background = Color(0xFF0B1326); // Deep Midnight Canvas
  static const surface = Color(0xFF131B2E);    // Dark Slate
  static const surfaceLow = Color(0xFF060E20); // Deep Canvas
  static const surfaceHigh = Color(0xFF222A3D);
  static const surfaceHighest = Color(0xFF2D3449);
  
  static const onSurface = Color(0xFFDAE2FC);  // Crisp readable text
  static const onSurfaceVariant = Color(0xFFC6C6CC); // Muted text/labels
  static const outline = Color(0xFF909096);
  static const outlineVariant = Color(0xFF46464C);
  
  // Protective Cyan (Safe & Active monitoring status)
  static const cyan = Color(0xFF00E5FF);
  static const cyanDim = Color(0xFF00DAF3);
  static const cyanGlow = Color(0x3300E5FF);
  static const cyanSurface = Color(0xFF00363D);

  // Threat Alert Crimson
  static const crimson = Color(0xFFFF2A4D);
  static const crimsonGlow = Color(0x4DFF2A4D);
  static const crimsonContainer = Color(0xFF93000A);
  static const onCrimsonContainer = Color(0xFFFFDAD6);
}

class AuraTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraColors.background,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        surface: AuraColors.surface,
        primary: AuraColors.cyan,
        secondary: AuraColors.cyanDim,
        error: AuraColors.crimson,
        onSurface: AuraColors.onSurface,
      ),
      cardTheme: CardThemeData(
        color: AuraColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      useMaterial3: true,
    );
  }
}
