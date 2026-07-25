/// Purpose: Re-export the shared foreground sync wake lock.
/// Inputs: None (library declaration only).
/// Returns: N/A.
/// Side effects: None.
/// Notes: `SyncWakeLock` moved to the `myapps_data` package verbatim
/// (PLAN.md P2.1) — the three apps' copies were byte-identical (SHA-256
/// verified). This file stays so every existing import keeps working (I7).
/// The lock is still acquired and released by the pages that run foreground
/// operations, not by the sync engine (feature-matrix G17/G21).
library;

export 'package:myapps_data/myapps_data.dart' show SyncWakeLock;
