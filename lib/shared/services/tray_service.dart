import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';

class TrayService with TrayListener, WindowListener {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `TrayService._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  TrayService._();
  static final TrayService instance = TrayService._();

  static const _dockChannel = MethodChannel('com.yuanzhe.my_anime/dock');

  bool _minimizeToTray = false;
  bool _closeToTray = false;
  bool _initialized = false;
  Locale _locale = const Locale('en');

  /// Purpose: Implement the minimize to tray behavior for this file.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get minimizeToTray => _minimizeToTray;

  /// Purpose: Implement the close to tray behavior for this file.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get closeToTray => _closeToTray;

  /// Purpose: Implement the init behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    final config = await AnimeStorage.readConfig();
    _minimizeToTray = config['minimizeToTray'] as bool? ?? false;
    _closeToTray = config['closeToTray'] as bool? ?? false;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(_closeToTray);

    await _setupTray();
    trayManager.addListener(this);

    _initialized = true;
  }

  /// Purpose: Provide the internal setup tray helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _setupTray() async {
    final iconPath = Platform.isWindows
        ? 'assets/icon/app_icon.ico'
        : 'assets/icon/app_icon.png';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('MyAnime!!!!!');
    await _rebuildMenu();
  }

  /// Purpose: Provide the internal rebuild menu helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _rebuildMenu() async {
    final l10n = lookupAppLocalizations(_locale);
    final menu = Menu(
      items: [
        MenuItem(key: 'show', label: l10n.trayShow),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: l10n.trayQuit),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Purpose: Update minimize to tray with the provided value.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    final config = await AnimeStorage.readConfig();
    config['minimizeToTray'] = value;
    await AnimeStorage.writeConfig(config);
  }

  /// Purpose: Update close to tray with the provided value.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    final config = await AnimeStorage.readConfig();
    config['closeToTray'] = value;
    await AnimeStorage.writeConfig(config);
    await windowManager.setPreventClose(value);
  }

  /// Purpose: Update locale with the provided value or current state.
  /// Inputs: `locale`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  Future<void> updateLocale(Locale locale) async {
    _locale = locale;
    if (_initialized) await _rebuildMenu();
  }

  // ─── TrayListener ──

  /// Purpose: Implement the on tray icon mouse down behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  /// Purpose: Implement the on tray icon right mouse down behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// Purpose: Implement the on tray menu item click behavior for this file.
  /// Inputs: `menuItem`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'quit':
        windowManager.setPreventClose(false);
        windowManager.close();
        break;
    }
  }

  // ─── WindowListener ──

  /// Purpose: Implement the on window close behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  @override
  void onWindowClose() {
    if (_closeToTray) {
      windowManager.hide();
      _setDockIconVisible(false);
    } else {
      windowManager.destroy();
    }
  }

  /// Purpose: Implement the on window minimize behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  @override
  void onWindowMinimize() {
    if (_minimizeToTray) {
      windowManager.hide();
      _setDockIconVisible(false);
    }
  }

  // ─── macOS Dock ──

  /// Purpose: Provide the internal show window helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _showWindow() {
    _setDockIconVisible(true);
    windowManager.show();
    windowManager.focus();
  }

  /// Purpose: Provide the internal set dock icon visible helper for this file.
  /// Inputs: `visible`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static void _setDockIconVisible(bool visible) {
    if (!Platform.isMacOS) return;
    _dockChannel.invokeMethod('setDockIconVisible', {'visible': visible});
  }
}
