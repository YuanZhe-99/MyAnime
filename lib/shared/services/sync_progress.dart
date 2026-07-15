import 'package:flutter/foundation.dart';

/// High-level phase of a WebDAV sync, force-upload, or force-download run.
enum SyncPhase {
  idle,
  connecting,
  downloadingData,
  merging,
  uploadingData,
  uploadingImages,
  downloadingImages,
  done,
  error,
}

/// Immutable snapshot of sync progress reported by `WebDAVService.progress`.
///
/// The service reports only the phase enum plus raw file names and counts;
/// UI code maps the phase to a localized status string.
class SyncProgress {
  final SyncPhase phase;

  /// Optional raw detail, e.g. the data file or image name being transferred,
  /// or the error message for [SyncPhase.error].
  final String? detail;

  /// 1-based index of the current item when [total] is greater than zero.
  final int current;

  /// Total item count for the current phase; zero means indeterminate.
  final int total;

  /// Purpose: Create an immutable sync progress snapshot.
  /// Inputs: `phase`, optional `detail`, `current`, `total`.
  /// Returns: A new `SyncProgress` instance.
  /// Side effects: None.
  /// Notes: `total == 0` means the phase has no measurable item count.
  const SyncProgress(
    this.phase, {
    this.detail,
    this.current = 0,
    this.total = 0,
  });

  /// The resting state shown when no sync operation is running.
  static const idle = SyncProgress(SyncPhase.idle);

  /// Purpose: Return the completed fraction of the current phase.
  /// Inputs: None.
  /// Returns: `double?` in 0..1, or null when the phase is indeterminate.
  /// Side effects: None.
  /// Notes: Bind this to a `LinearProgressIndicator.value` directly.
  double? get fraction =>
      total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null;

  /// Purpose: Return whether a sync/force operation is currently running.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: `done` and `error` are terminal, not running, states.
  bool get isRunning =>
      phase != SyncPhase.idle &&
      phase != SyncPhase.done &&
      phase != SyncPhase.error;
}

/// Purpose: Expose a `ValueListenable` type alias for sync progress consumers.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: UI pages listen with `ValueListenableBuilder<SyncProgress>`.
typedef SyncProgressListenable = ValueListenable<SyncProgress>;
