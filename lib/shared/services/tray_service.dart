import 'dart:io';
import 'dart:ui';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';

class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _minimizeToTray = false;
  bool _closeToTray = false;
  bool _initialized = false;
  Locale _locale = const Locale('en');

  bool get minimizeToTray => _minimizeToTray;
  bool get closeToTray => _closeToTray;

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

  Future<void> _setupTray() async {
    final iconPath =
        Platform.isWindows ? 'assets/icon/app_icon.ico' : 'assets/icon/app_icon.png';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('MyAnime!!!!!');
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final l10n = lookupAppLocalizations(_locale);
    final menu = Menu(items: [
      MenuItem(key: 'show', label: l10n.trayShow),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: l10n.trayQuit),
    ]);
    await trayManager.setContextMenu(menu);
  }

  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    final config = await AnimeStorage.readConfig();
    config['minimizeToTray'] = value;
    await AnimeStorage.writeConfig(config);
  }

  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    final config = await AnimeStorage.readConfig();
    config['closeToTray'] = value;
    await AnimeStorage.writeConfig(config);
    await windowManager.setPreventClose(value);
  }

  Future<void> updateLocale(Locale locale) async {
    _locale = locale;
    if (_initialized) await _rebuildMenu();
  }

  // ─── TrayListener ──

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'quit':
        windowManager.setPreventClose(false);
        windowManager.close();
        break;
    }
  }

  // ─── WindowListener ──

  @override
  void onWindowClose() {
    if (_closeToTray) {
      windowManager.hide();
    } else {
      windowManager.destroy();
    }
  }

  @override
  void onWindowMinimize() {
    if (_minimizeToTray) {
      windowManager.hide();
    }
  }
}
