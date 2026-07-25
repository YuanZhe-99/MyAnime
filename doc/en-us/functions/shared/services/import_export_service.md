# lib/shared/services/import_export_service.dart

**Partly a facade.** The ZIP half (`exportZIP` / `importZIP`) delegates to the `myapps_data` package
(`lib/src/data/zip_transfer.dart`). The Markdown export is deeply domain-specific and stays here.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`exportZIP(destDir)`](#exportzip) | static method | A | Write `myanime_export_<stamp>.zip`. |
| [`importZIP(filePath)`](#importzip) | static method | A | Restore data and images from an export. |
| [`exportMarkdown(destDir)`](#exportmarkdown) | static method | A | Write a Markdown record of all anime. |

Private label helpers for the Markdown export (`_typeLabel`, `_dayLabel`, `_deriveStatus`, and the
rest) are unchanged and remain in this file.

## Documentation

### `exportZIP(destDir)` <a id="exportzip"></a>
- **Returns:** `Future<String?>` — the written path, or null on failure.
- **Side effects:** Writes `myanime_export_<yyyyMMdd_HHmmss>.zip`.
- **Notes:** Bundles the registry's data files plus flat `images/<basename>` entries. Config,
  `.sync_base/`, and `backups/` are never included.

### `importZIP(filePath)` <a id="importzip"></a>
- **Returns:** `Future<bool>` — true on success.
- **Side effects:** Overwrites allowlisted data files and images.
- **Notes:** Only allowlisted entries are extracted (the registry's data files and flat files under
  `images/`), and every entry must resolve inside the app dir, so a crafted ZIP cannot overwrite
  `webdav_config.json`.

  **Behavior change from the extraction:** every entry is classified before any is written, so an
  archive containing a path-traversal entry is now rejected outright — the call returns false and
  nothing is written — rather than skipping the bad entry and importing the rest. Unknown entries are
  still skipped, so an archive from a newer build still imports. Payloads are written as raw bytes
  without UTF-8 or model validation, as before.

### `exportMarkdown(destDir)` <a id="exportmarkdown"></a>
- **Returns:** `Future<String?>` — the written path, or null on failure.
- **Side effects:** Writes `myanime_export_<yyyyMMdd_HHmmss>.md`.
- **Notes:** Sorted by first air date with nulls last, then by display title. Reads the data-file
  name from the registry. Designed for LLM personalization context.

## Where the engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/data/zip_transfer.md`.
