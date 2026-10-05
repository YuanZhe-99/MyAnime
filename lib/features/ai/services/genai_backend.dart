import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:myapps_ai/myapps_ai.dart' as shared;

export 'package:myapps_ai/myapps_ai.dart'
    show
        GenAiBackend,
        GenAiStatus,
        GenAiFailure,
        GenAiException,
        GenAiStatusReport,
        GenAiCoreInfo,
        platformMayHaveOnDeviceModel;

/// MyAnime's existing native channel over the shared backend implementation.
class MethodChannelGenAiBackend extends shared.MethodChannelGenAiBackend {
  /// Purpose: Bind the shared backend to MyAnime. Inputs: test channel.
  /// Returns: Backend. Side effects: None. Notes: Keeps existing native registration.
  MethodChannelGenAiBackend([MethodChannel? channel])
    : super(channel ?? const MethodChannel(channelName));

  static const channelName = shared.MethodChannelGenAiBackend.channelName;

  /// Purpose: Map a native error. Inputs: code. Returns: failure.
  /// Side effects: None. Notes: Compatibility for app tests.
  @visibleForTesting
  static shared.GenAiFailure failureForCode(String code) =>
      // This compatibility entry point is itself restricted to tests.
      // ignore: invalid_use_of_visible_for_testing_member
      shared.MethodChannelGenAiBackend.failureForCode(code);
}
