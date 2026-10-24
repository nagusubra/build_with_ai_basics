import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class BakeShapes {
  static const cardRadius = 22.0;
  static const buttonRadius = 16.0;

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: BakeColors.deepCherry.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

ThemeData buildBakeTheme() {
  const fontFamily = 'Nunito';
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BakeColors.cherryRed,
      primary: BakeColors.cherryRed,
      secondary: BakeColors.leafGreen,
      surface: BakeColors.warmCream,
      onSurface: BakeColors.charcoal,
    ),
    scaffoldBackgroundColor: BakeColors.warmCream,
    // A browser on a Mac or PC would otherwise get compact desktop controls, desktop page
    // animations and back arrows; the web version should look and move like the iPhone app.
    visualDensity: VisualDensity.standard,
    platform: kIsWeb ? TargetPlatform.iOS : null,
  );

  final text = base.textTheme.apply(
    bodyColor: BakeColors.charcoal,
    displayColor: BakeColors.deepCherry,
    fontFamily: fontFamily,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
    ),
    // Flutter's web build always draws a Material back arrow; use the iPhone chevron there too.
    actionIconTheme: kIsWeb
        ? ActionIconThemeData(backButtonIconBuilder: (_) => const Icon(Icons.arrow_back_ios_new_rounded))
        : null,
    appBarTheme: const AppBarTheme(
      backgroundColor: BakeColors.warmCream,
      foregroundColor: BakeColors.deepCherry,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: BakeColors.deepCherry,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BakeColors.cherryRed,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BakeShapes.buttonRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BakeColors.deepCherry,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: BakeColors.cherryRed, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BakeShapes.buttonRadius),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BakeShapes.cardRadius),
        side: const BorderSide(color: BakeColors.line),
      ),
    ),
  );
}
