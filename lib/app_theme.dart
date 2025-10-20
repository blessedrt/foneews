import 'package:flutter/material.dart';

ThemeData appThemeDark() {
  const primary = Color(0xFF6C63FF);    // Modern indigo
  const secondary = Color(0xFF00D9F5);   // Bright cyan
  const surface = Color(0xFF1E1E2E);     // Deep blue-grey
  const background = Color(0xFF13131A);  // Near black
  
  return ThemeData.dark().copyWith(
    useMaterial3: true,  // Enable Material 3
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      background: background,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: surface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: secondary,
      foregroundColor: Colors.black,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    ),
  );
}