import 'package:wakelock_plus/wakelock_plus.dart';

/// Purpose: Keep the device/screen awake while a foreground sync operation
/// (manual sync, conflict finalize, force upload/download) is running.
/// Inputs: None.
/// Returns: None.
/// Side effects: Enables/disables the platform wake lock through
/// `wakelock_plus`.
/// Notes: Reference-counted so overlapping foreground operations share one
/// lock. Ownership-tracked so releasing never disables a wake lock that some
/// other feature (for example a page-held lock) enabled first. Background
/// auto-sync must not use this class. All plugin calls swallow errors so a
/// wake-lock failure can never break a sync operation.
class SyncWakeLock {
  /// Purpose: Prevent instantiation; this class only has static members.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  SyncWakeLock._();

  static int _refCount = 0;
  static bool _enabledBySync = false;

  /// Purpose: Acquire the sync wake lock for one foreground operation.
  /// Inputs: None.
  /// Returns: A future that completes once the wake lock state is applied.
  /// Side effects: On the first concurrent acquire, enables the platform wake
  /// lock unless another feature already holds it.
  /// Notes: Always pair with `release()` in a `finally` block so completion,
  /// failure, cancellation, and exceptions all release the lock. Plugin
  /// errors are swallowed.
  static Future<void> acquire() async {
    _refCount++;
    if (_refCount > 1) return;
    try {
      final alreadyEnabled = await WakelockPlus.enabled;
      if (!alreadyEnabled) {
        await WakelockPlus.enable();
        _enabledBySync = true;
      }
    } catch (_) {
      // Wake lock is best-effort; never let it break sync.
    }
  }

  /// Purpose: Release the sync wake lock for one foreground operation.
  /// Inputs: None.
  /// Returns: A future that completes once the wake lock state is applied.
  /// Side effects: On the last concurrent release, disables the platform wake
  /// lock if and only if `acquire()` enabled it.
  /// Notes: Safe to call when nothing is held. Plugin errors are swallowed.
  static Future<void> release() async {
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount > 0 || !_enabledBySync) return;
    _enabledBySync = false;
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Wake lock is best-effort; never let it break sync.
    }
  }
}
