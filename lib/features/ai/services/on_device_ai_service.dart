import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'genai_backend.dart';

/// How far a model download has got.
@immutable
class GenAiDownload {
  /// Purpose: Describe download progress.
  /// Inputs: `bytes`, `total` — -1 when unknown.
  /// Returns: A new `GenAiDownload`.
  /// Side effects: None.
  /// Notes: None.
  const GenAiDownload({required this.bytes, required this.total});

  /// Bytes fetched so far.
  final int bytes;

  /// Total bytes, or -1 when the system has not said.
  final int total;

  /// Purpose: Return the fraction done.
  /// Inputs: None.
  /// Returns: `double?` — null when the total is unknown.
  /// Side effects: None.
  /// Notes: None.
  double? get fraction => total > 0 ? (bytes / total).clamp(0.0, 1.0) : null;
}

/// Who is waiting for a request, which decides its place in the queue.
enum AiPriority {
  /// A user is looking at the result (recommendation reasons).
  interactive,

  /// Nobody is waiting (category classification).
  background,
}

/// One queued request.
class _AiJob<T> {
  _AiJob(this.priority, this.body);

  final AiPriority priority;
  final Future<T> Function(GenAiBackend backend) body;
  final completer = Completer<T>();

  /// Purpose: Run the body once, with a timeout.
  /// Inputs: `backend`, `timeout`.
  /// Returns: `Future<T>` — throws what the body throws, or a timeout.
  /// Side effects: Runs the model.
  /// Notes: Internal helper used within this file only. The completer is
  /// settled by the queue afterwards, once pacing has been applied, so a
  /// caller that sees the failure also sees its effect on the queue.
  Future<T> attempt(GenAiBackend backend, Duration timeout) =>
      body(backend).timeout(
        timeout,
        onTimeout: () => throw const GenAiException(GenAiFailure.timeout),
      );

  /// Purpose: Settle the completer with a value.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Completes the future.
  /// Notes: Internal helper used within this file only.
  void succeed(Object? value) {
    if (!completer.isCompleted) completer.complete(value as T);
  }

  /// Purpose: Settle the completer with an error.
  /// Inputs: `error`, `stackTrace`.
  /// Returns: None.
  /// Side effects: Completes the future with an error.
  /// Notes: Internal helper used within this file only.
  void failWith(Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
  }

  /// Purpose: Settle the completer with a failure without running.
  /// Inputs: `failure`.
  /// Returns: None.
  /// Side effects: Completes the future with an error.
  /// Notes: Internal helper used within this file only.
  void fail(GenAiFailure failure) {
    if (!completer.isCompleted) {
      completer.completeError(GenAiException(failure));
    }
  }
}

/// Owns the on-device AI policy: whether it may run at all, what the model can
/// do right now, and the one-at-a-time queue.
///
/// **The load-bearing rule is that while the user's switch is off, the backend
/// is never called at all — not even for status.** Every public method checks
/// [enabled] first. Background work runs only while the app is resumed, which
/// Android's foreground rule requires and Apple's background rate limit
/// rewards. Adapted from MyNihongo!!!!!'s `AiAssistService`.
class OnDeviceAiService extends ChangeNotifier {
  /// Purpose: Create the service.
  /// Inputs: `backend`; `now` — clock, injectable for tests.
  /// Returns: A new `OnDeviceAiService`.
  /// Side effects: None.
  /// Notes: Off until [setEnabled] turns it on.
  OnDeviceAiService({GenAiBackend? backend, DateTime Function()? now})
    : _backend = backend ?? MethodChannelGenAiBackend(),
      _now = now ?? DateTime.now;

  /// The app-wide instance.
  static OnDeviceAiService instance = OnDeviceAiService();

  /// Purpose: Replace the singleton for a test.
  /// Inputs: `service`.
  /// Returns: None.
  /// Side effects: Points [instance] at another service.
  /// Notes: Test-only.
  @visibleForTesting
  static void setInstanceForTest(OnDeviceAiService service) =>
      instance = service;

  /// How long one request may take before it is given up on. Generous,
  /// because a first inference after a cold start pages the model in.
  static const timeout = Duration(seconds: 45);

  /// The longest wait after the system reports it is busy.
  static const maxBackoff = Duration(minutes: 5);

  /// The first wait after the system reports it is busy.
  static const initialBackoff = Duration(seconds: 5);

  final GenAiBackend _backend;
  final DateTime Function() _now;

  bool _enabled = false;
  bool _preferFast = false;
  GenAiStatusReport _report = GenAiStatusReport.unsupported;
  GenAiCoreInfo? _coreInfo;
  GenAiDownload? _download;
  bool _downloading = false;

  bool _resumed = true;
  bool _running = false;
  final _queue = ListQueue<_AiJob<Object?>>();
  DateTime? _pausedUntil;
  Duration _backoff = initialBackoff;
  DateTime? _quotaDay;
  Timer? _resumeTimer;
  AppLifecycleListener? _lifecycle;

  /// Whether the user turned on-device AI on. Off until they do.
  bool get enabled => _enabled;

  /// Whether the smaller model is preferred where a device serves both.
  bool get preferFast => _preferFast;

  /// The model's status, as last asked.
  GenAiStatusReport get report => _report;

  /// The device's model-system details, as last asked.
  GenAiCoreInfo? get coreInfo => _coreInfo;

  /// Progress of the running download, if any.
  GenAiDownload? get downloadProgress => _download;

  /// Whether a download is running.
  bool get downloading => _downloading;

  /// Whether a request is running.
  bool get busy => _running;

  /// Whether background work is paused until a time, after a busy reply.
  DateTime? get pausedUntil => _pausedUntil;

  /// Whether background work stopped for today after a quota reply.
  bool get quotaReachedToday {
    final day = _quotaDay;
    if (day == null) return false;
    final n = _now();
    return day.year == n.year && day.month == n.month && day.day == n.day;
  }

  /// Purpose: Report whether the model can generate right now.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Uses the last status; every request re-checks it anyway.
  bool get canGenerate => _enabled && _report.status == GenAiStatus.available;

  /// Purpose: Turn on-device AI on or off.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Refreshes the status when switched on; when switched off,
  /// cancels the running request, fails everything queued, forgets the status
  /// and never calls the backend again until switched back on.
  /// Notes: Persisting the choice is `AppSettingsNotifier`'s job.
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    if (value) {
      await refreshStatus();
    } else {
      final wasRunning = _running;
      _failQueued(GenAiFailure.unavailable);
      _report = GenAiStatusReport.unsupported;
      _coreInfo = null;
      if (wasRunning) await _backend.cancel();
      notifyListeners();
    }
  }

  /// Purpose: Choose the larger or the faster model.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Re-probes when enabled; notifies listeners.
  /// Notes: None.
  Future<void> setPreferFast(bool value) async {
    if (_preferFast == value) return;
    _preferFast = value;
    if (_enabled) {
      await refreshStatus();
    } else {
      notifyListeners();
    }
  }

  /// Purpose: Ask the device what the model can do.
  /// Inputs: `localeTag` — for Apple's `supportsLocale` report.
  /// Returns: None.
  /// Side effects: Queries the platform (forced re-probe); notifies listeners.
  /// Notes: Does nothing while the switch is off. Called when the switch goes
  /// on, when Settings opens, and from "Check again".
  Future<void> refreshStatus({String? localeTag}) async {
    if (!_enabled) return;
    if (!platformMayHaveOnDeviceModel) {
      _report = GenAiStatusReport.unsupported;
      notifyListeners();
      return;
    }
    _report = await _backend.statusReport(force: true, preferFast: _preferFast);
    _coreInfo = await _backend.coreInfo(localeTag: localeTag);
    notifyListeners();
  }

  /// Purpose: Ask the system to fetch the model (Android).
  /// Inputs: None.
  /// Returns: `Future<bool>` — whether the model is usable afterwards.
  /// Side effects: The **system** downloads a model over the network.
  /// Notes: Refused while the switch is off or a request runs. Started only
  /// from the Download button in Settings, never on the user's behalf.
  Future<bool> download() async {
    if (!_enabled || _running || _downloading) return false;
    _downloading = true;
    _download = const GenAiDownload(bytes: 0, total: -1);
    notifyListeners();
    try {
      await _backend.download(
        onProgress: (bytes, total) {
          _download = GenAiDownload(
            bytes: bytes,
            total: total > 0 ? total : (_download?.total ?? -1),
          );
          notifyListeners();
        },
      );
    } on GenAiException {
      // Reported through the status below.
    } finally {
      _downloading = false;
      _download = null;
    }
    _report = await _backend.statusReport(preferFast: _preferFast);
    notifyListeners();
    return _report.status == GenAiStatus.available;
  }

  /// Purpose: Generate one answer through the queue.
  /// Inputs: `instructions`, `prompt`, `maxOutputTokens`, `priority`.
  /// Returns: `Future<String>` — throws [GenAiException] on failure.
  /// Side effects: Runs the model on the device when its turn comes.
  /// Notes: Refused at once while the switch is off.
  Future<String> generate({
    required String instructions,
    required String prompt,
    int maxOutputTokens = 256,
    AiPriority priority = AiPriority.interactive,
  }) => _enqueue(
    priority,
    (b) => b.generate(
      instructions: instructions,
      prompt: prompt,
      maxOutputTokens: maxOutputTokens,
    ),
  );

  /// Purpose: Ask the model to pick from a fixed list, through the queue.
  /// Inputs: `instructions`, `prompt`, `options`, `maxItems`, `priority`.
  /// Returns: `Future<List<String>>` — throws [GenAiException] on failure.
  /// Side effects: Runs the model on the device when its turn comes.
  /// Notes: The caller validates the ids again against its own list.
  Future<List<String>> choose({
    required String instructions,
    required String prompt,
    required List<String> options,
    int maxItems = 3,
    AiPriority priority = AiPriority.background,
  }) => _enqueue(
    priority,
    (b) => b.choose(
      instructions: instructions,
      prompt: prompt,
      options: options,
      maxItems: maxItems,
    ),
  );

  /// Purpose: Load the model ahead of a batch.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May page the model in.
  /// Notes: Does nothing while the switch is off.
  Future<void> prewarm() async {
    if (!_enabled || !canGenerate) return;
    await _backend.prewarm();
  }

  /// Purpose: Stop the running request and drop queued background work.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the platform request.
  /// Notes: Interactive requests already queued stay queued.
  Future<void> cancelBackground() async {
    final kept = _queue
        .where((j) => j.priority == AiPriority.interactive)
        .toList();
    for (final j in _queue) {
      if (j.priority == AiPriority.background) j.fail(GenAiFailure.cancelled);
    }
    _queue
      ..clear()
      ..addAll(kept);
    if (_running && _enabled) await _backend.cancel();
  }

  /// Purpose: Start following the app lifecycle.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers an `AppLifecycleListener` once.
  /// Notes: Called from `main` after the binding exists. Calls nothing on the
  /// backend: the switch still decides whether anything ever runs.
  void start() {
    _lifecycle ??= AppLifecycleListener(onStateChange: handleLifecycle);
  }

  /// Purpose: Follow the app lifecycle.
  /// Inputs: `state`.
  /// Returns: None.
  /// Side effects: Pauses or resumes the queue.
  /// Notes: Called by the listener [start] registers. Nothing runs
  /// while the app is not resumed; the queue resumes on the next resume.
  void handleLifecycle(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _pump();
  }

  /// Purpose: Queue a request.
  /// Inputs: `priority`, `body`.
  /// Returns: `Future<T>`.
  /// Side effects: Starts the queue.
  /// Notes: Internal helper used within this file only.
  Future<T> _enqueue<T>(
    AiPriority priority,
    Future<T> Function(GenAiBackend backend) body,
  ) {
    if (!_enabled) {
      return Future.error(const GenAiException(GenAiFailure.unavailable));
    }
    if (priority == AiPriority.background && quotaReachedToday) {
      return Future.error(const GenAiException(GenAiFailure.quota));
    }
    final job = _AiJob<T>(priority, body);
    if (priority == AiPriority.interactive) {
      // Ahead of every background job, behind earlier interactive ones.
      final list = _queue.toList();
      final at = list.indexWhere((j) => j.priority == AiPriority.background);
      if (at < 0) {
        _queue.add(job);
      } else {
        list.insert(at, job);
        _queue
          ..clear()
          ..addAll(list);
      }
    } else {
      _queue.add(job);
    }
    scheduleMicrotask(_pump);
    return job.completer.future;
  }

  /// Purpose: Run the next eligible job.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Runs at most one job at a time; re-arms itself.
  /// Notes: Internal helper used within this file only. A background job
  /// waits while the app is not resumed, while a busy backoff is in force,
  /// and fails once today's quota is reached.
  Future<void> _pump() async {
    if (_running || _queue.isEmpty || !_enabled || !_resumed) return;
    final head = _queue.first;
    if (head.priority == AiPriority.background) {
      if (quotaReachedToday) {
        _failQueued(GenAiFailure.quota, onlyBackground: true);
        return;
      }
      final until = _pausedUntil;
      if (until != null && _now().isBefore(until)) {
        _resumeTimer?.cancel();
        _resumeTimer = Timer(until.difference(_now()), _pump);
        return;
      }
    }
    _queue.removeFirst();
    _running = true;
    notifyListeners();
    try {
      // Re-checked before every use: the system can remove a model between
      // two requests.
      _report = await _backend.statusReport(preferFast: _preferFast);
      if (!_enabled) {
        head.fail(GenAiFailure.unavailable);
      } else if (_report.status != GenAiStatus.available) {
        head.fail(GenAiFailure.unavailable);
      } else {
        try {
          final value = await head.attempt(_backend, timeout);
          _pace(null);
          head.succeed(value);
        } catch (e, st) {
          _pace(e is GenAiException ? e.failure : GenAiFailure.failed);
          head.failWith(e, st);
        }
      }
    } finally {
      _running = false;
      notifyListeners();
    }
    unawaited(_pump());
  }

  /// Purpose: Adjust pacing after a job finished.
  /// Inputs: `failure` — null on success.
  /// Returns: None.
  /// Side effects: Sets the busy backoff, the quota stop, or the wait for
  /// resume.
  /// Notes: Internal helper used within this file only.
  void _pace(GenAiFailure? failure) {
    switch (failure) {
      case GenAiFailure.busy:
        _pausedUntil = _now().add(_backoff);
        final doubled = _backoff * 2;
        _backoff = doubled > maxBackoff ? maxBackoff : doubled;
      case GenAiFailure.quota:
        _quotaDay = _now();
      case GenAiFailure.background:
        _resumed = false;
      case null:
        _backoff = initialBackoff;
        _pausedUntil = null;
      default:
        break;
    }
  }

  /// Purpose: Fail queued jobs.
  /// Inputs: `failure`; `onlyBackground`.
  /// Returns: None.
  /// Side effects: Completes queued futures with errors and removes them.
  /// Notes: Internal helper used within this file only.
  void _failQueued(GenAiFailure failure, {bool onlyBackground = false}) {
    final kept = <_AiJob<Object?>>[];
    for (final j in _queue) {
      if (onlyBackground && j.priority == AiPriority.interactive) {
        kept.add(j);
      } else {
        j.fail(failure);
      }
    }
    _queue
      ..clear()
      ..addAll(kept);
  }

  /// Purpose: Release timers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the resume timer and the lifecycle listener.
  /// Notes: Flutter `ChangeNotifier` override.
  @override
  void dispose() {
    _resumeTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}

/// The on-device AI service, read by Settings and the features that use it.
///
/// A plain `Provider` over the singleton, as MyNihongo does, so a rebuilt
/// `ProviderScope` never disposes the app-wide service. Consumers listen to it
/// directly.
final onDeviceAiServiceProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService.instance,
);
