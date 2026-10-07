import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_ai/myapps_ai.dart' as shared;

import 'genai_backend.dart';
import 'ai_source_backend.dart';

export 'package:myapps_ai/myapps_ai.dart' show AiPriority, GenAiDownload;

/// App-owned instance and providers over shared execution.
class OnDeviceAiService extends shared.OnDeviceAiService {
  /// Purpose: Construct app service. Inputs: backend, clock.
  /// Returns: Service. Side effects: None. Notes: Defaults to the app-owned source router; test injection is retained.
  OnDeviceAiService({GenAiBackend? backend, super.now})
    : super(backend: backend ?? sourceBackend);

  static final sourceBackend = AiSourceBackend();

  static OnDeviceAiService instance = OnDeviceAiService();
  static const timeout = shared.OnDeviceAiService.timeout;
  static const initialBackoff = shared.OnDeviceAiService.initialBackoff;
  static const maxBackoff = shared.OnDeviceAiService.maxBackoff;

  /// Purpose: Replace app instance in tests. Inputs: service. Returns: None.
  /// Side effects: Replaces singleton. Notes: Provider retains app ownership.
  @visibleForTesting
  static void setInstanceForTest(OnDeviceAiService service) =>
      instance = service;
}

final onDeviceAiServiceProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService.instance,
);
