# lib/features/settings/views/privacy_policy_page.dart

`PrivacyPolicyPage` is a static, locale-aware settings sub-page reached from Settings -> About ->
Privacy Policy (see `functions/features/settings/views/settings_page.md`). It is a
`StatelessWidget` with no service dependencies: `build` resolves the current `Locale` via
`Localizations.localeOf(context)` and hands it to the one piece of real logic in the file,
`_getText`, which picks one of four hard-coded privacy-policy string constants (`_en`, `_zh`,
`_zhTW`, `_ja`) to render in a scrollable `SelectableText`. The policy text itself documents the
app's actual network/data behavior (no analytics, WebDAV sync only when the user configures it,
local-only backups, and the optional AI features: off by default; what a source is given; system AI
(1.6.0), local models downloaded from Hugging Face (1.8.11) and user-added online sources used only
while selected and after their notice is accepted (1.8.11); where results are kept (rewritten in
1.8.12; custom Hugging Face models after a warning and the GPU only when turned on, 1.9.0) — see [`../../../../on-device-ai.md`](../../../../on-device-ai.md)) —
see [`../../../backup-restore.md`](../../../../backup-restore.md) and
[`../../../sync.md`](../../../../sync.md) for the mechanisms it describes in prose. `build` appends
the localized WebDAV notice lines (`webdavPrivacyPlaintext`, `webdavPrivacyHttp`,
`webdavPrivacyPaused`) after the policy; the AI lines it appended in 1.8.11 are part of the policy
text since 1.8.12.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `PrivacyPolicyPage({super.key})` | constructor (`PrivacyPolicyPage`) | B | Create a privacy policy page instance. |
| `build` | method (widget build) | B | Resolve the current locale and render the matching static policy text. |
| [`_getText`](#gettext) | method (`PrivacyPolicyPage`) | A | Select the locale-appropriate static privacy-policy text. |

## Documentation

### `String _getText(Locale locale)` <a id="gettext"></a>
- **Kind:** method of `PrivacyPolicyPage`
- **Source:** `lib/features/settings/views/privacy_policy_page.dart` (line 41)
- **Purpose:** Choose which language variant of the static privacy-policy text to display, based
  on the widget tree's current locale.
- **Inputs:** `locale` — the `Locale` resolved via `Localizations.localeOf(context)` in `build`.
- **Returns:** One of the four static `String` constants defined lower in the class: `_zhTW`,
  `_zh`, `_ja`, or `_en`.
- **Side effects:** None.
- **Algorithm:**
  1. If `locale.languageCode == 'zh'` **and** `locale.countryCode == 'TW'`, return `_zhTW`
     (Traditional Chinese) immediately — this specific check runs first because it is a narrower
     match than the plain `'zh'` case below.
  2. Otherwise `switch` on `locale.languageCode`: `'zh'` -> `_zh` (Simplified Chinese), `'ja'` ->
     `_ja` (Japanese).
  3. Any other language code, including one with no match in the switch, falls through to
     `default` and returns `_en` (English).
- **Usage:**
  ```dart
  // From PrivacyPolicyPage.build:
  final locale = Localizations.localeOf(context);
  final text = _getText(locale);
  ```
- **Notes:** The Traditional-Chinese branch requires both `languageCode == 'zh'` **and**
  `countryCode == 'TW'`; a `zh` locale with a different or absent country code (e.g. `zh_CN`, or a
  bare `zh` with no country) does not hit that first check and instead falls through to the
  `switch`, which matches the plain `'zh'` case and returns `_zh` (Simplified), not `_zhTW`.


## Changes in 1.6.4

All four policy texts disclose directory fetching, video host requests, temporary native credentials and the embedded website profile/third-party resources.


Current integration uses MyApps-AI v0.6.0, explicit platform injection, the shared source router (`createAiSourceRouter`) and the unified settings skeleton. WebDAV entry points require device-local notice acknowledgement before any network request; see [sync.md](../../../sync.md).
