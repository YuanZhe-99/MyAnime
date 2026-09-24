import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'output_validation.dart';

/// Purpose: Report whether this platform can have an on-device model at all.
/// Inputs: None.
/// Returns: `bool` — true on Android (AICore), iOS and macOS (Foundation
/// Models); false on Windows, Linux and the web.
/// Side effects: None.
/// Notes: A coarse gate. Everywhere else the backend answers
/// [GenAiStatus.unsupported] without touching the method channel, and Settings
/// shows no AI rows. Whether a given device actually has a model is a run-time
/// question answered by `OnDeviceAiService.refreshStatus()`.
bool get platformMayHaveOnDeviceModel =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// What the on-device model can do on this device, right now.
enum GenAiStatus {
  /// This platform has no on-device model at all. Never asked the device.
  unsupported,

  /// The device cannot run the model — no AICore, an ineligible device, or a
  /// model this device is not offered. The system was asked and said no.
  unavailable,

  /// The system could not be asked at all: the call threw, or the channel is
  /// not registered. A different fact from [unavailable], with a different fix.
  unreachable,

  /// Apple Intelligence is off in system settings; the user can turn it on.
  notEnabled,

  /// The model is not on the device yet, and the system can fetch it
  /// (Android only; the app asks AICore to download it).
  downloadable,

  /// The system is fetching or preparing the model. Apple's `modelNotReady`
  /// maps here.
  downloading,

  /// Ready to use.
  available,

  /// The system answered with a status this build has no name for. Reported as
  /// itself rather than folded into [unavailable].
  unknown,
}

/// Why a generation attempt did not produce an answer.
enum GenAiFailure {
  /// The model is not usable on this device, or the feature is off.
  unavailable,

  /// Another request is already running, or the system is busy.
  busy,

  /// The model ran but produced nothing usable, or the platform errored.
  failed,

  /// The request was cancelled.
  cancelled,

  /// The input was longer than the model accepts.
  tooLong,

  /// The model did not answer in time.
  timeout,

  /// The app was not in the foreground; Android refuses background inference.
  background,

  /// The system's per-app quota or rate limit was reached.
  quota,

  /// The model's safety guardrail refused the request.
  guardrail,

  /// The request's language is not supported by the model.
  unsupportedLanguage,
}

/// Thrown by a backend when a call cannot produce a result.
class GenAiException implements Exception {
  /// Purpose: Create a generation failure.
  /// Inputs: `failure`, and the platform's own `message` for logs.
  /// Returns: A new `GenAiException`.
  /// Side effects: None.
  /// Notes: `message` is never shown to the user.
  const GenAiException(this.failure, [this.message]);

  /// Which failure this is, for the UI to word.
  final GenAiFailure failure;

  /// The platform's own message, for logs only.
  final String? message;

  /// Purpose: Describe the failure for logs.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => 'GenAiException(${failure.name}, $message)';
}

/// The model's status plus what the device said about it.
class GenAiStatusReport {
  /// Purpose: Describe the model's availability.
  /// Inputs: `status`; `code` — the platform's own value, -1 when it threw or
  /// has none; `detail` — a short untranslated line; `variant`, `served`,
  /// `refused` — Android's probe results; `baseModelName`, `tokenLimit`.
  /// Returns: A new `GenAiStatusReport`.
  /// Side effects: None.
  /// Notes: `detail` is an identifier to quote in a bug report, not prose,
  /// so it is not localized.
  const GenAiStatusReport(
    this.status, {
    this.code = -1,
    this.detail,
    this.variant,
    this.served,
    this.refused,
    this.baseModelName,
    this.tokenLimit,
  });

  /// What the model can do.
  final GenAiStatus status;

  /// The platform's raw status value; -1 when the call threw or has none.
  final int code;

  /// A short diagnostic line, or null.
  final String? detail;

  /// Which Android model variant answered, such as `stable/full`.
  final String? variant;

  /// Every Android variant the device served, comma-separated.
  final String? served;

  /// The Android variants the device refused, comma-separated.
  final String? refused;

  /// The name of the model actually serving, when one is.
  final String? baseModelName;

  /// The serving model's token limit, when known.
  final int? tokenLimit;

  /// A report for a platform that was never asked.
  static const unsupported = GenAiStatusReport(GenAiStatus.unsupported);

  /// Purpose: Say whether the served variants include both model sizes.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Decides whether Settings offers "Prefer the faster model"; a
  /// control that cannot change anything is not shown.
  bool get hasSizeChoice {
    final s = served;
    return s != null && s.contains('/full') && s.contains('/fast');
  }

  /// Purpose: Read the map the platform channel sends.
  /// Inputs: `answer`.
  /// Returns: `GenAiStatusReport`.
  /// Side effects: None.
  /// Notes: Unknown status names become [GenAiStatus.unknown]; a missing or
  /// non-string status becomes [GenAiStatus.unavailable]. Missing fields are
  /// absent rather than wrong.
  static GenAiStatusReport fromJson(Map<Object?, Object?>? answer) {
    final name = answer?['status'];
    final status = switch (name) {
      'available' => GenAiStatus.available,
      'unsupported' => GenAiStatus.unsupported,
      'downloadable' => GenAiStatus.downloadable,
      'downloading' => GenAiStatus.downloading,
      'unavailable' => GenAiStatus.unavailable,
      'unreachable' => GenAiStatus.unreachable,
      'notEnabled' => GenAiStatus.notEnabled,
      'unknown' => GenAiStatus.unknown,
      String() => GenAiStatus.unknown,
      _ => GenAiStatus.unavailable,
    };
    final code = answer?['code'];
    final tokenLimit = answer?['tokenLimit'];
    return GenAiStatusReport(
      status,
      code: code is int ? code : -1,
      detail: answer?['detail']?.toString(),
      variant: answer?['variant']?.toString(),
      served: answer?['served']?.toString(),
      refused: answer?['refused']?.toString(),
      baseModelName: answer?['baseModelName']?.toString(),
      tokenLimit: tokenLimit is int ? tokenLimit : null,
    );
  }
}

/// What the device's on-device model system is: AICore on Android, the OS
/// and Apple Intelligence on Apple platforms.
class GenAiCoreInfo {
  /// Purpose: Describe the device's model system.
  /// Inputs: `platform`, `installed`, `versionName`, `sdk`, `device`,
  /// `compatible`, `osVersion`, `localeSupported`.
  /// Returns: A new `GenAiCoreInfo`.
  /// Side effects: None.
  /// Notes: Reading AICore's version needs the manifest's `<queries>` entry.
  const GenAiCoreInfo({
    this.platform,
    this.installed = false,
    this.versionName,
    this.sdk,
    this.device,
    this.compatible,
    this.osVersion,
    this.localeSupported,
  });

  /// `android` or `apple`, as the platform reported it.
  final String? platform;

  /// Whether AICore is present (Android), or the framework exists (Apple).
  final bool installed;

  /// The AICore build.
  final String? versionName;

  /// The Android API level.
  final int? sdk;

  /// Manufacturer and model.
  final String? device;

  /// Whether ML Kit considers AICore usable here, or null when unknown.
  final bool? compatible;

  /// The Apple OS version string.
  final String? osVersion;

  /// Whether the model supports the app's current locale (Apple).
  final bool? localeSupported;

  /// Purpose: Read the map the platform channel sends.
  /// Inputs: `json`.
  /// Returns: `GenAiCoreInfo?` — null when the platform sent nothing usable.
  /// Side effects: None.
  /// Notes: None.
  static GenAiCoreInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    return GenAiCoreInfo(
      platform: json['platform']?.toString(),
      installed: json['installed'] == true,
      versionName: json['versionName']?.toString(),
      sdk: json['sdk'] is int ? json['sdk'] as int : null,
      device: json['device']?.toString(),
      compatible: json['compatible'] is bool
          ? json['compatible'] as bool
          : null,
      osVersion: json['osVersion']?.toString(),
      localeSupported: json['localeSupported'] is bool
          ? json['localeSupported'] as bool
          : null,
    );
  }
}

/// The seam between `OnDeviceAiService` and the platform's model.
///
/// A `flutter_test` run has no AICore and no Foundation Models, and everything
/// worth testing — the switch, the status handling, the prompts, the parsing —
/// is on the service's side of this seam.
abstract class GenAiBackend {
  /// Purpose: Ask what the model can do, and what the device said about it.
  /// Inputs: `force` — re-probe rather than trust a serving model;
  /// `preferFast` — ask for the smaller model where a device serves both.
  /// Returns: `Future<GenAiStatusReport>`.
  /// Side effects: Queries the platform.
  /// Notes: Never throws.
  Future<GenAiStatusReport> statusReport({
    bool force = false,
    bool preferFast = false,
  });

  /// Purpose: Describe the device's model system.
  /// Inputs: `localeTag` — the app's current locale, for Apple's
  /// `supportsLocale` check.
  /// Returns: `Future<GenAiCoreInfo?>`.
  /// Side effects: Queries the platform.
  /// Notes: Never throws.
  Future<GenAiCoreInfo?> coreInfo({String? localeTag});

  /// Purpose: Ask the system to fetch the model (Android only).
  /// Inputs: `onProgress` — bytes downloaded and the total, -1 when unknown.
  /// Returns: `Future<bool>` — true when the download completed.
  /// Side effects: The **system** downloads a model over the network.
  /// Notes: The app never downloads anything itself.
  Future<bool> download({void Function(int bytes, int total)? onProgress});

  /// Purpose: Generate one answer.
  /// Inputs: `instructions`, `prompt`, `maxOutputTokens`, `temperature`,
  /// `topK`.
  /// Returns: `Future<String>` — possibly empty.
  /// Side effects: Runs the model on the device.
  /// Notes: Throws [GenAiException] rather than returning a failure.
  Future<String> generate({
    required String instructions,
    required String prompt,
    int maxOutputTokens = 256,
    double temperature = 0,
    int topK = 1,
  });

  /// Purpose: Pick up to `maxItems` of `options`.
  /// Inputs: `instructions`, `prompt`, `options`, `maxItems`.
  /// Returns: `Future<List<String>>` — chosen options, possibly empty; the
  /// raw reply is validated again by the caller.
  /// Side effects: Runs the model on the device.
  /// Notes: Constrained decoding on Apple; on Android this is [generate] plus
  /// the line parser. Throws [GenAiException].
  Future<List<String>> choose({
    required String instructions,
    required String prompt,
    required List<String> options,
    int maxItems = 3,
  });

  /// Purpose: Load the model ahead of a batch.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May page the model in.
  /// Notes: Best effort; never throws.
  Future<void> prewarm();

  /// Purpose: Stop whatever is running.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the in-flight platform request.
  /// Notes: Safe to call when nothing is running.
  Future<void> cancel();
}

/// The real backend, talking to `GenAiChannel` on Android and the
/// `on_device_ai_apple` plugin on iOS and macOS, over one channel name.
class MethodChannelGenAiBackend implements GenAiBackend {
  /// Purpose: Create the channel backend.
  /// Inputs: `channel` — injectable for tests.
  /// Returns: A new `MethodChannelGenAiBackend`.
  /// Side effects: None.
  /// Notes: Nothing is sent until a method is called.
  MethodChannelGenAiBackend([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  /// The channel name, matched by `GenAiChannel.CHANNEL` in Kotlin and the
  /// Apple plugin's registration.
  static const channelName = 'com.yuanzhe.my_anime/genai';

  final MethodChannel _channel;

  void Function(int bytes, int total)? _onProgress;
  bool _listening = false;

  /// Purpose: Ask the platform for the model's status.
  /// Inputs: `force`, `preferFast`.
  /// Returns: `Future<GenAiStatusReport>`.
  /// Side effects: One channel call.
  /// Notes: A `MissingPluginException` is [GenAiStatus.unreachable] with the
  /// detail "channel not registered" — never `unsupported` — so a plugin that
  /// failed to register is noticed.
  @override
  Future<GenAiStatusReport> statusReport({
    bool force = false,
    bool preferFast = false,
  }) async {
    if (!platformMayHaveOnDeviceModel) return GenAiStatusReport.unsupported;
    try {
      final answer = await _channel.invokeMapMethod<Object?, Object?>(
        'status',
        {'feature': 'prompt', 'force': force, 'preferFast': preferFast},
      );
      return GenAiStatusReport.fromJson(answer);
    } on MissingPluginException {
      return const GenAiStatusReport(
        GenAiStatus.unreachable,
        detail: 'channel not registered',
      );
    } on PlatformException catch (error) {
      return GenAiStatusReport(
        GenAiStatus.unreachable,
        detail: '${error.code}: ${error.message}',
      );
    } catch (error) {
      return GenAiStatusReport(
        GenAiStatus.unreachable,
        detail: error.runtimeType.toString(),
      );
    }
  }

  /// Purpose: Read the device's model-system details.
  /// Inputs: `localeTag`.
  /// Returns: `Future<GenAiCoreInfo?>` — null off the supported platforms and
  /// whenever the call fails.
  /// Side effects: One channel call.
  /// Notes: A diagnostic; failing to gather it never breaks Settings.
  @override
  Future<GenAiCoreInfo?> coreInfo({String? localeTag}) async {
    if (!platformMayHaveOnDeviceModel) return null;
    try {
      return GenAiCoreInfo.fromJson(
        await _channel.invokeMapMethod<Object?, Object?>('info', {
          'locale': ?localeTag,
        }),
      );
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Ask the system to fetch the model.
  /// Inputs: `onProgress`.
  /// Returns: `Future<bool>`.
  /// Side effects: The system downloads a model; progress arrives as method
  /// calls from the platform.
  /// Notes: The progress handler is registered lazily and once.
  @override
  Future<bool> download({
    void Function(int bytes, int total)? onProgress,
  }) async {
    if (!platformMayHaveOnDeviceModel) {
      throw const GenAiException(GenAiFailure.unavailable);
    }
    _onProgress = onProgress;
    if (!_listening) {
      _channel.setMethodCallHandler(_handlePlatformCall);
      _listening = true;
    }
    try {
      final done = await _channel.invokeMethod<bool>('download', {
        'feature': 'prompt',
      });
      return done ?? false;
    } on PlatformException catch (e) {
      throw GenAiException(failureForCode(e.code), e.message);
    } on MissingPluginException catch (e) {
      throw GenAiException(GenAiFailure.unavailable, e.message);
    } finally {
      _onProgress = null;
    }
  }

  /// Purpose: Generate one answer.
  /// Inputs: `instructions`, `prompt`, `maxOutputTokens`, `temperature`,
  /// `topK`.
  /// Returns: `Future<String>`.
  /// Side effects: Runs the model on the device.
  /// Notes: None.
  @override
  Future<String> generate({
    required String instructions,
    required String prompt,
    int maxOutputTokens = 256,
    double temperature = 0,
    int topK = 1,
  }) async {
    if (!platformMayHaveOnDeviceModel) {
      throw const GenAiException(GenAiFailure.unavailable);
    }
    try {
      final text = await _channel.invokeMethod<String>('generate', {
        'instructions': instructions,
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'temperature': temperature,
        'topK': topK,
      });
      return text ?? '';
    } on PlatformException catch (e) {
      throw GenAiException(failureForCode(e.code), e.message);
    } on MissingPluginException catch (e) {
      throw GenAiException(GenAiFailure.unavailable, e.message);
    }
  }

  /// Purpose: Pick up to `maxItems` of `options`.
  /// Inputs: `instructions`, `prompt`, `options`, `maxItems`.
  /// Returns: `Future<List<String>>`.
  /// Side effects: Runs the model on the device.
  /// Notes: Apple answers natively with constrained decoding; Android
  /// generates text and [parseChoiceReply] reads it. A reply that ignores the
  /// format is a [GenAiFailure.failed].
  @override
  Future<List<String>> choose({
    required String instructions,
    required String prompt,
    required List<String> options,
    int maxItems = 3,
  }) async {
    if (!platformMayHaveOnDeviceModel) {
      throw const GenAiException(GenAiFailure.unavailable);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final reply = await generate(
        instructions: instructions,
        prompt: prompt,
        maxOutputTokens: 64,
      );
      final parsed = parseChoiceReply(reply, options, maxItems: maxItems);
      if (!parsed.valid) {
        throw const GenAiException(GenAiFailure.failed, 'unparseable reply');
      }
      return parsed.ids;
    }
    try {
      final chosen = await _channel.invokeListMethod<Object?>('choose', {
        'instructions': instructions,
        'prompt': prompt,
        'options': options,
        'maxItems': maxItems,
      });
      return [
        for (final c in chosen ?? const <Object?>[])
          if (c is String) c,
      ];
    } on PlatformException catch (e) {
      throw GenAiException(failureForCode(e.code), e.message);
    } on MissingPluginException catch (e) {
      throw GenAiException(GenAiFailure.unavailable, e.message);
    }
  }

  /// Purpose: Load the model ahead of a batch.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: One channel call.
  /// Notes: Errors are swallowed; prewarming is advisory.
  @override
  Future<void> prewarm() async {
    if (!platformMayHaveOnDeviceModel) return;
    try {
      await _channel.invokeMethod<void>('prewarm');
    } catch (_) {
      // Advisory only.
    }
  }

  /// Purpose: Stop whatever is running.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the in-flight platform request.
  /// Notes: Errors are swallowed; cancelling is best effort.
  @override
  Future<void> cancel() async {
    if (!platformMayHaveOnDeviceModel) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {
      // The request either finished or will be discarded.
    }
  }

  /// Purpose: Receive download progress from the platform.
  /// Inputs: `call`.
  /// Returns: None.
  /// Side effects: Calls the current progress callback.
  /// Notes: Internal helper used within this file only.
  Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method != 'downloadProgress') return;
    final args = call.arguments;
    if (args is! Map) return;
    _onProgress?.call(
      (args['bytes'] as num?)?.toInt() ?? 0,
      (args['total'] as num?)?.toInt() ?? -1,
    );
  }

  /// Purpose: Map a platform error code to a failure.
  /// Inputs: `code`.
  /// Returns: `GenAiFailure`.
  /// Side effects: None.
  /// Notes: The codes `GenAiChannel` and the Apple plugin send; anything else
  /// is `failed`.
  @visibleForTesting
  static GenAiFailure failureForCode(String code) => switch (code) {
    'unavailable' => GenAiFailure.unavailable,
    'busy' => GenAiFailure.busy,
    'cancelled' => GenAiFailure.cancelled,
    'tooLong' => GenAiFailure.tooLong,
    'background' => GenAiFailure.background,
    'quota' => GenAiFailure.quota,
    'guardrail' => GenAiFailure.guardrail,
    'unsupportedLanguage' => GenAiFailure.unsupportedLanguage,
    _ => GenAiFailure.failed,
  };
}
