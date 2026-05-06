import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBgDark = Color(0xFF0F0F0F);
const kBgSecondary = Color(0xFF1A1A1A);
const kBgTertiary = Color(0xFF242424);
const kBorderColor = Color(0xFF2E2E2E);
const kAccentBlue = Color(0xFF00A6FF);
const kTextPrimary = Color(0xFFFFFFFF);
const kTextSecondary = Color(0xFF9CA3AF);
const kTextMuted = Color(0xFF6B7280);
const kSuccessGreen = Color(0xFF22C55E);
const kErrorRed = Color(0xFFEF4444);

ThemeData buildTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: kBgDark,
    colorScheme: const ColorScheme.dark(
      primary: kAccentBlue,
      secondary: kAccentBlue,
      surface: kBgSecondary,
      error: kErrorRed,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      bodyLarge: GoogleFonts.inter(color: kTextPrimary),
      bodyMedium: GoogleFonts.inter(color: kTextSecondary),
      bodySmall: GoogleFonts.inter(color: kTextMuted),
      titleLarge: GoogleFonts.inter(
        color: kTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: kTextPrimary,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBgTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccentBlue, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: kTextMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentBlue,
        foregroundColor: kTextPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextPrimary,
        side: const BorderSide(color: kBorderColor),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    dividerColor: kBorderColor,
    cardColor: kBgSecondary,
  );
}
