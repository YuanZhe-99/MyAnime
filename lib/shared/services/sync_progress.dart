/// Purpose: Re-export the shared sync progress model.
/// Inputs: None (library declaration only).
/// Returns: N/A.
/// Side effects: None.
/// Notes: `SyncPhase`, `SyncProgress`, and `SyncProgressListenable` moved to the
/// `myapps_data` package verbatim — the three apps' copies were
/// byte-identical (SHA-256 verified). This file stays so every existing import
/// keeps working unchanged (I7).
library;

export 'package:myapps_data/myapps_data.dart'
    show SyncPhase, SyncProgress, SyncProgressListenable;
