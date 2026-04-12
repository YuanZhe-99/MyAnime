import 'dart:io';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'shared/services/auto_sync_service.dart';
import 'shared/services/backup_service.dart';
import 'shared/services/file_open_service.dart';
import 'shared/services/local_api_server.dart';
import 'shared/services/reminder_service.dart';
import 'shared/services/tray_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup launch-at-startup on desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  // Start local HTTP API server if enabled (desktop only)
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await LocalApiServer.start();
  }

  // Initialise system tray on desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await TrayService.instance.init();
  }

  // Initialize local notifications.
  await ReminderService.init();

  // Run auto-backup if enabled (once per day, fire-and-forget)
  BackupService.runAutoBackupIfNeeded();

  // Start auto-sync lifecycle observer
  AutoSyncService.instance.start();

  // Start periodic reminder check (every 60s)
  ReminderService.startPeriodicCheck();

  // Initialize file open handler (MethodChannel for mobile file associations)
  FileOpenService.init();

  // Check command-line args for .myanimeitem file (desktop cold start)
  final openFile = args
      .where((a) => a.endsWith('.myanimeitem'))
      .firstOrNull;
  if (openFile != null) {
    FileOpenService.setPendingFile(openFile);
  }

  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (_) => const ProviderScope(
        child: MyAnimeApp(),
      ),
    ),
  );

  // Process pending file after the first frame
  if (openFile != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FileOpenService.processPendingFile();
    });
  }
}


