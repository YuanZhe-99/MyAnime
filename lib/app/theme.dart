import 'package:flutter/material.dart';

class AppTheme {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AppTheme._` instance.
  /// Side effects: None.
  /// Notes: Never called; the class is a namespace.
  AppTheme._();

  /// The app's brand color and the only per-app knob of the visual system.
  /// Every role of the stock Material 3 tonal palette is generated from it
  /// whenever the platform supplies no dynamic scheme. Each app in the series
  /// has its own seed so they are told apart at a glance; MyAnime's is deep
  /// purple.
  static const Color seedColor = Color(0xFF673AB7);

  /// Purpose: Resolve the color scheme for one brightness.
  /// Inputs: `brightness`; `dynamicScheme` — the platform's wallpaper-derived
  /// scheme for that brightness, or null.
  /// Returns: `ColorScheme` — the dynamic scheme when given, otherwise
  /// `ColorScheme.fromSeed(seedColor)`.
  /// Side effects: None.
  /// Notes: Which platforms may pass a dynamic scheme is decided by the caller
  /// (`MyAnimeApp.build` allows Android only).
  static ColorScheme scheme(
    Brightness brightness, [
    ColorScheme? dynamicScheme,
  ]) =>
      dynamicScheme ??
      ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

  /// Purpose: Build a stock Material 3 theme for one brightness.
  /// Inputs: `brightness`; `dynamicScheme` — optional platform scheme.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: Deliberately close to Flutter's Material 3 defaults. The only
  /// component override is outlined text fields, which the M3 spec allows and
  /// which keep every form looking as it did before 1.7.0.
  static ThemeData build(Brightness brightness, [ColorScheme? dynamicScheme]) =>
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme(brightness, dynamicScheme),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  /// Purpose: Return the light theme used by the app.
  /// Inputs: `dynamicScheme` — optional light platform scheme.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData light([ColorScheme? dynamicScheme]) =>
      build(Brightness.light, dynamicScheme);

  /// Purpose: Return the dark theme used by the app.
  /// Inputs: `dynamicScheme` — optional dark platform scheme.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData dark([ColorScheme? dynamicScheme]) =>
      build(Brightness.dark, dynamicScheme);
}
