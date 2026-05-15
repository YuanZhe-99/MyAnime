import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AppTheme._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  AppTheme._();

  /// Purpose: Return the light Material theme used by the app.
  /// Inputs: None.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData get light => FlexThemeData.light(
    scheme: FlexScheme.deepPurple,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      navigationBarLabelBehavior:
          NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    useMaterial3: true,
  );

  /// Purpose: Return the dark Material theme used by the app.
  /// Inputs: None.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData get dark => FlexThemeData.dark(
    scheme: FlexScheme.deepPurple,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      navigationBarLabelBehavior:
          NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    useMaterial3: true,
  );
}
