import 'package:flutter/material.dart';

const _seed = Color(0xFF5B6CFF);
const appBackground = Color(0xFFF7F8FC);
const lapseColor = Color(0xFFE5645A);

const List<int> habitColors = [
  0xFF5B6CFF,
  0xFF22B8A0,
  0xFFFF8A5B,
  0xFFE95D8C,
  0xFFF4B740,
  0xFF8E6CEF,
];

/// Colour with a given opacity (0..1) without deprecated APIs.
Color tint(Color c, double opacity) => c.withAlpha((opacity * 255).round());

BoxDecoration cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: tint(const Color(0xFF1B2559), 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: appBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: tint(_seed, 0.15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
