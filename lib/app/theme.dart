import 'package:flutter/material.dart';
import 'package:myapps_ui/myapps_ui.dart';

export 'package:myapps_ui/myapps_ui.dart' show AppUiStyle, NavPlacement;

/// Application brand facade over the shared theme implementation.
class AppTheme {
  /// Purpose: Prevent instantiation of the application facade.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Static API retained for existing callers.
  AppTheme._();

  /// Original application brand color.
  static const seedColor = Color(0xFF673AB7);
  static const _theme = MyAppsTheme(seedColor: seedColor);

  /// Purpose: Resolve the application palette.
  /// Inputs: `brightness`, optional `dynamicScheme`.
  /// Returns: ColorScheme.
  /// Side effects: None.
  /// Notes: Dynamic-color platform policy remains caller-owned.
  static ColorScheme scheme(
    Brightness brightness, [
    ColorScheme? dynamicScheme,
  ]) => _theme.scheme(brightness, dynamicScheme);

  /// Purpose: Build the shared theme with the application brand.
  /// Inputs: `brightness`, optional `dynamicScheme` and `style`.
  /// Returns: ThemeData.
  /// Side effects: None.
  /// Notes: Expressive remains the default.
  static ThemeData build(
    Brightness brightness, [
    ColorScheme? dynamicScheme,
    AppUiStyle style = AppUiStyle.expressive,
  ]) => _theme.build(brightness, dynamicScheme, style);

  /// Purpose: Build the light application theme.
  /// Inputs: Optional `dynamicScheme` and `style`.
  /// Returns: ThemeData.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData light([
    ColorScheme? dynamicScheme,
    AppUiStyle style = AppUiStyle.expressive,
  ]) => build(Brightness.light, dynamicScheme, style);

  /// Purpose: Build the dark application theme.
  /// Inputs: Optional `dynamicScheme` and `style`.
  /// Returns: ThemeData.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData dark([
    ColorScheme? dynamicScheme,
    AppUiStyle style = AppUiStyle.expressive,
  ]) => build(Brightness.dark, dynamicScheme, style);
}
