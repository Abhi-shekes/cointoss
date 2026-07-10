import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Peaky Blinders-era palette: charcoal, gunmetal, oxblood, aged brass.
class AppColors {
  static const Color ink = Color(0xFF0B0B0D); // near-black background
  static const Color charcoal = Color(0xFF17171B);
  static const Color gunmetal = Color(0xFF2A2D33);
  static const Color oxblood = Color(0xFF5A1A1A);
  static const Color oxbloodDeep = Color(0xFF3A0F0F);
  static const Color brass = Color(0xFFC9A04E);
  static const Color brassLight = Color(0xFFF3D89A);
  static const Color brassDeep = Color(0xFF8A6B2E);
  static const Color amber = Color(0xFFE8A54B); // tungsten glow
  static const Color smoke = Color(0xFF9A958C);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brass,
        secondary: AppColors.oxblood,
        surface: AppColors.charcoal,
      ),
      textTheme: _textTheme(base.textTheme),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    // Cinzel: engraved, coin-like display serif. Oswald: condensed UI sans.
    final display = GoogleFonts.cinzelTextTheme(base);
    final body = GoogleFonts.oswaldTextTheme(base);
    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AppColors.brassLight,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
      ),
      titleLarge: body.titleLarge?.copyWith(
        color: AppColors.smoke,
        letterSpacing: 8,
        fontWeight: FontWeight.w300,
      ),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.smoke),
    );
  }
}
