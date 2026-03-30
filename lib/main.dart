import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'shared/services/auto_sync_service.dart';
import 'shared/services/backup_service.dart';
import 'shared/services/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications.
  await ReminderService.init();

  // Run auto-backup if enabled (once per day, fire-and-forget)
  BackupService.runAutoBackupIfNeeded();

  // Start auto-sync lifecycle observer
  AutoSyncService.instance.start();

  // Start periodic reminder check (every 60s)
  ReminderService.startPeriodicCheck();

  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (_) => const ProviderScope(
        child: MyAnimeApp(),
      ),
    ),
  );
}


