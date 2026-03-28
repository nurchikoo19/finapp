import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tabys design system — dark navy + gold
class TColors {
  TColors._();

  static const ink     = Color(0xFF08101E);
  static const surface = Color(0xFF0E1928);
  static const card    = Color(0xFF111F33);
  static const card2   = Color(0xFF152340);
  static const border  = Color(0xFF1E3054);
  static const border2 = Color(0xFF253D66);

  static const gold     = Color(0xFFD4A843);
  static const goldBg   = Color(0x14D4A843); // ~8% opacity
  static const goldGlow = Color(0x2ED4A843); // ~18% opacity

  static const green    = Color(0xFF2DD4A0);
  static const greenBg  = Color(0x142DD4A0);
  static const greenGlow= Color(0x262DD4A0); // ~15% opacity

  static const red      = Color(0xFFF06464);
  static const redBg    = Color(0x14F06464);
  static const redGlow  = Color(0x26F06464); // ~15% opacity

  static const blue     = Color(0xFF5B9CF6);
  static const blueBg   = Color(0x145B9CF6);
  static const blueGlow = Color(0x265B9CF6); // ~15% opacity

  static const text    = Color(0xFFEBF2FF);
  static const muted   = Color(0xFF5A7299);
  static const muted2  = Color(0xFF3D5478);
}

class TabysTheme {
  TabysTheme._();

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.ibmPlexMono(
          fontSize: size, fontWeight: weight, color: color ?? TColors.text);

  static TextStyle syne({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.syne(
          fontSize: size, fontWeight: weight, color: color ?? TColors.text);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TColors.ink,
      colorScheme: const ColorScheme.dark(
        primary: TColors.gold,
        onPrimary: TColors.ink,
        secondary: TColors.green,
        onSecondary: TColors.ink,
        surface: TColors.card,
        onSurface: TColors.text,
        error: TColors.red,
        outline: TColors.border,
        outlineVariant: TColors.border2,
        surfaceContainerHighest: TColors.card2,
        surfaceContainer: TColors.surface,
      ),
      cardTheme: const CardThemeData(
        color: TColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: TColors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(color: TColors.text),
        titleTextStyle: GoogleFonts.syne(
            fontSize: 18, fontWeight: FontWeight.w700, color: TColors.text),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: TColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TColors.border),
        ),
      ),
      textTheme: TextTheme(
        displayLarge:   GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: TColors.text),
        displayMedium:  GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w700, color: TColors.text),
        displaySmall:   GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700, color: TColors.text),
        headlineMedium: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: TColors.text),
        headlineSmall:  GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: TColors.text),
        titleLarge:     GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: TColors.text),
        titleMedium:    GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: TColors.text),
        titleSmall:     GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600, color: TColors.text),
        bodyLarge:      GoogleFonts.inter(fontSize: 14, color: TColors.text),
        bodyMedium:     GoogleFonts.inter(fontSize: 13, color: TColors.text),
        bodySmall:      GoogleFonts.inter(fontSize: 11, color: TColors.muted),
        labelLarge:     GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: TColors.text),
        labelMedium:    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: TColors.muted),
        labelSmall:     GoogleFonts.inter(fontSize: 10, color: TColors.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TColors.card,
        labelStyle: const TextStyle(color: TColors.muted),
        hintStyle: const TextStyle(color: TColors.muted2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TColors.red),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TColors.gold,
          foregroundColor: TColors.ink,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TColors.blue,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TColors.text,
          side: const BorderSide(color: TColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
          color: TColors.border, space: 0, thickness: 1),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: TColors.goldBg,
        iconColor: TColors.muted,
        textColor: TColors.muted,
        selectedColor: TColors.gold,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TColors.card2,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: TColors.text),
        side: const BorderSide(color: TColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: TColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: TColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TColors.card2,
        contentTextStyle: GoogleFonts.inter(color: TColors.text),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: TColors.border)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: TColors.card2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: TColors.border),
        ),
        textStyle: GoogleFonts.inter(fontSize: 11, color: TColors.text),
      ),
    );
  }
}
