import 'package:flutter/material.dart';

/// BusWhere design tokens — mirrors tokens/*.css from the design system.
class BW {
  BW._();

  // Brand base
  static const night = Color(0xFF12222E);
  static const busYellow = Color(0xFFF5A623);
  static const teal = Color(0xFF0E7C7B);
  static const sand = Color(0xFFF6F5F1);
  static const white = Color(0xFFFFFFFF);

  // Night scale
  static const night700 = Color(0xFF2A3A46);
  static const night600 = Color(0xFF475561);
  static const night500 = Color(0xFF6B7782);
  static const night300 = Color(0xFFC4CCD2);
  static const night200 = Color(0xFFDEE2E5);

  // Sand scale
  static const sand300 = Color(0xFFE6E4DD);
  static const sand200 = Color(0xFFEFEDE7);

  // Teal scale
  static const teal700 = Color(0xFF0A5F5E);
  static const teal300 = Color(0xFF5FD3D0);
  static const teal100 = Color(0xFFDDF1F0);

  // Yellow scale (shapes only — never small text on white)
  static const yellow600 = Color(0xFFDB8F12);
  static const yellow100 = Color(0xFFFDEFD6);

  // Status
  static const red600 = Color(0xFFB3261E);
  static const red100 = Color(0xFFFBE3E1);
  static const onDarkMuted = Color(0xFFC4D5DF);

  // Semantic
  static const textPrimary = night;
  static const textSecondary = night600;
  static const textPlaceholder = night500;
  static const borderSubtle = sand300;
  static const scrim = Color(0x8C12222E); // 55% Night

  // Radii
  static const rSm = 12.0; // inputs, chips, icon tiles
  static const rMd = 16.0; // buttons
  static const rLg = 20.0; // cards
  static const rXl = 24.0; // sheets, dialogs, header blocks

  // Spacing
  static const gutter = 16.0;
  static const contentMax = 480.0;

  // Motion
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const easeOut = Cubic(0.2, 0.7, 0.3, 1);

  static const shadowFloat = [BoxShadow(color: Color(0x1F12222E), blurRadius: 8, offset: Offset(0, 2))];
}

/// Type scale — Sora only. Bold for headings/numbers, Regular body, SemiBold labels.
class BWText {
  BWText._();
  static const _f = 'Sora';
  static const display = TextStyle(fontFamily: _f, fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.64);
  static const h1 = TextStyle(fontFamily: _f, fontSize: 26, height: 32 / 26, fontWeight: FontWeight.w700);
  static const h2 = TextStyle(fontFamily: _f, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700);
  static const h3 = TextStyle(fontFamily: _f, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700);
  static const bodyLg = TextStyle(fontFamily: _f, fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w400);
  static const body = TextStyle(fontFamily: _f, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const small = TextStyle(fontFamily: _f, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontFamily: _f, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const eta = TextStyle(fontFamily: _f, fontSize: 40, height: 44 / 40, fontWeight: FontWeight.w700, letterSpacing: -0.8);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Sora',
    scaffoldBackgroundColor: BW.sand,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BW.teal,
      primary: BW.busYellow,
      onPrimary: BW.night,
      secondary: BW.teal,
      onSecondary: BW.white,
      surface: BW.sand,
      onSurface: BW.night,
      error: BW.red600,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: BW.teal, selectionColor: BW.teal100, selectionHandleColor: BW.teal),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
