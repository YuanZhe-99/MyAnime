# lib/features/ai/widgets/ai_settings_tiles.dart

`AiSettingsTiles`, added in 1.6.0 (M3), builds the on-device AI rows of the *Categories & recommendations*
Settings section: the "Use on-device AI" switch, the model status row with its
action, "Prefer the faster model" (Android, only when both sizes are served), the notes on who owns
the model, and a collapsed *Technical details* tile. On Windows, Linux and the web it renders
nothing. Since 1.6.0 (M4) `settings_page.dart` places it after the feature switches; since M5 it passes
`featuresOn: autoCategoriesEnabled || recommendationsEnabled`, so the AI switch can be turned on only
while automatic categories or recommendations are on, and turning the last of them off also turns AI
off. See
[`../services/on_device_ai_service.md`](../services/on_device_ai_service.md) and
[`../../../../on-device-ai.md`](../../../../on-device-ai.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiSettingsTiles.new` | constructor (`AiSettingsTiles`) | B | Create the AI settings rows; `featuresOn` says whether a feature that uses the model is on. |
| `AiSettingsTiles.createState` | method (`AiSettingsTiles`) | B | Create the state object. |
| [`_AiSettingsTilesState.initState`](#_aisettingstilesstate-initstate) | method (`_AiSettingsTilesState`) | A | Refresh the model status when Settings opens. |
| `_AiSettingsTilesState._localeTag` | method (`_AiSettingsTilesState`) | B | Return the app's current locale as a tag such as `zh_TW`. |
| `_AiSettingsTilesState._statusLabel` | method (`_AiSettingsTilesState`) | B | Word a model status with the `aiStatus*` strings. |
| [`_AiSettingsTilesState.build`](#_aisettingstilesstate-build) | method (`_AiSettingsTilesState`) | A | Build the rows. |

The `featuresOn` field carries no `/// Purpose:` comment and is not a row.

## Documentation

### `void initState()` <a id="_aisettingstilesstate-initstate"></a>
- **Kind:** method of `_AiSettingsTilesState` (Flutter lifecycle override)
- **Source:** `lib/features/ai/widgets/ai_settings_tiles.dart` (approx. line 46)
- **Purpose:** Refresh the model status when Settings opens.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** After the first frame, one forced status probe — only while the switch is on.
- **Algorithm:** In a post-frame callback, if still mounted and `OnDeviceAiService.enabled`, call
  `refreshStatus(localeTag: _localeTag())`.
- **Usage:** Flutter calls it when the tiles are first inserted.
- **Notes:** The post-frame callback is needed because `_localeTag` reads `Localizations`.

### `Widget build(BuildContext context)` <a id="_aisettingstilesstate-build"></a>
- **Kind:** method of `_AiSettingsTilesState`
- **Source:** `lib/features/ai/widgets/ai_settings_tiles.dart` (approx. line 90)
- **Purpose:** Build the rows.
- **Inputs:** `context`.
- **Returns:** A `Column` of tiles, or `SizedBox.shrink()` when `platformMayHaveOnDeviceModel` is
  false.
- **Side effects:** None; the buttons call `OnDeviceAiService` and `AppSettingsNotifier`.
- **Algorithm:** Inside a `ListenableBuilder` on the service:
  1. The switch, bound to `AppSettings.onDeviceAiEnabled` and `setOnDeviceAiEnabled`. It is
     disabled while `featuresOn` is false and the switch is off, and its subtitle then adds
     `aiNeedsFeature`. It stays enabled while on, so it can always be turned off.
  2. Only while on: the status row. `notEnabled` adds the "turn on Apple Intelligence" line; a
     running download shows the MB so far. Its action is Download for `downloadable` on Android,
     and Check again for `unavailable`, `unreachable`, `notEnabled`, `unknown` and `downloading`.
  3. "Prefer the faster model", on Android only when `report.hasSizeChoice`.
  4. The notes: on Android, who downloads the model and why it cannot be removed here; on Apple,
     that the system manages it.
  5. A collapsed *Technical details* tile with selectable text: status name and code, detail,
     variant, served and refused variants, model name, token limit, AICore version (or "not
     installed"), SDK, device, compatibility, OS version and locale support, each only when known.
- **Usage:** `settings_page.dart`, the *Categories & recommendations* section
  (`AiSettingsTiles(featuresOn: settings.autoCategoriesEnabled || settings.recommendationsEnabled)`); `test/ai_settings_tiles_ui_test.dart`
  (per platform with `debugDefaultTargetPlatformOverride`).
- **Notes:** `unsupported` is worded as needing iOS 26 or macOS 26 with Apple Intelligence. It is
  what the Apple plugin reports on iOS and macOS older than 26.
