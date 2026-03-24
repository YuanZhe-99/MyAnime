import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  AppTheme._();

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
