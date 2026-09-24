# Platform Notes

Platform-specific caveats, plus the desktop-only local API server, tray behavior, and
launch-at-startup handling. See [`architecture.md`](architecture.md) for build flavors and
[`features/multi-source-search.md`](features/multi-source-search.md) for how the API server
reuses the shared search service.

## Windows

- The Inno Setup installer is defined in `installer.iss`; output goes to `build/installer/`.
- The installer creates Start Menu shortcuts — shortcuts are **not** created programmatically.
- App icon: `windows/runner/resources/app_icon.ico`.
- File association: `.myanimeitem` -> `MyAnimeItem` -> `my_anime.exe "%1"`, via registry entries
  in `installer.iss`.
- Inno uses `#ifdef ARM64` to build both x64 and ARM64 installers from one script.

## macOS

- App name is `MyAnime!!!!!` in `macos/Runner/Configs/AppInfo.xcconfig`.
- `com.apple.security.network.client` must be present in both `DebugProfile.entitlements` and
  `Release.entitlements` for network access.
- Custom app icons are generated with `flutter_launcher_icons`.
- `.myanimeitem` file association uses UTI `com.yuanzhe.my-anime.myanimeitem` in `Info.plist`.
- On-device AI (1.6.0) uses the same plugin and weak-link rules as iOS below; the deployment target
  stays macOS 13.0.

## iOS

- `CFBundleDisplayName` is `MyAnime!!!!!` in `Info.plist`.
- HTTPS network access needs no special entitlement.
- iOS app icons use dedicated padded sources for default, dark, and tinted modes:
  `assets/icon/app_icon_ios.png`, `assets/icon/app_icon_ios_dark.png`,
  `assets/icon/app_icon_ios_tinted.png`.
- `.myanimeitem` file association uses the same UTI declarations as macOS.
- App Store IPA requires signing/provisioning and is not built by CI.
- **On-device AI (1.6.0):** Apple's Foundation Models framework is bridged by the local Flutter
  plugin `packages/on_device_ai_apple/` (a tracked directory, not a submodule), declared with
  `sharedDarwinSource: true` so one Swift source serves iOS and macOS. It registers the
  `com.yuanzhe.my_anime/genai` channel and exposes no Dart API; the Flutter tool integrates it like
  any other plugin, so no `project.pbxproj` was edited. FoundationModels is **weak-linked**
  (`s.weak_frameworks` in the podspec; under Swift Package Manager the `@available` guards make the
  linker weak-link it) and every use sits behind `#if canImport(FoundationModels)` and
  `@available(iOS 26.0, macOS 26.0, *)`, so the deployment target stays iOS 13.0 and the app still
  launches on iOS 18 and earlier. Building the bridge needs the Xcode 26 SDK; with an older SDK
  `canImport` is false and the plugin answers `unsupported`. No entitlement or `Info.plist` key is
  needed. See [`on-device-ai.md`](on-device-ai.md).

## Android

- `android/app/build.gradle.kts` should use `import java.util.Properties`.
- **Kotlin migration state (app side migrated):** Gradle wrapper `9.3.1`, AGP `9.1.1`, and the app
  no longer applies `kotlin-android`. The Kotlin `jvmTarget` is set by a top-level
  `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` block — deliberately **not**
  `jvmToolchain` (which requires a real JDK 17 install) and **not** `kotlinOptions` (removed).
  `android/gradle.properties` keeps the Flutter-migrator compat flags `android.builtInKotlin=false`
  and `android.newDsl=false`, because several plugins still apply Kotlin Gradle Plugin (KGP)
  directly — setting `builtInKotlin=true` breaks every KGP-applying plugin (verified). Keep
  `org.jetbrains.kotlin.android` declared (`apply false`) in `settings.gradle.kts`; KGP-applying
  plugins resolve it from there.
- **`file_picker` is pinned to exactly `10.3.7`** (not a caret constraint) because it is the last
  release that both applies KGP itself (required while `builtInKotlin=false`) *and* compiles
  against `flutter.compileSdkVersion` (required by AGP 9 AAR metadata checks). `10.3.9+` and
  `11.x` rely on AGP's built-in Kotlin and fail to compile in compat mode; `10.3.2` and older pin
  `compileSdk 34` and fail the metadata check. Its Dart API is `FilePicker.platform.*`.
- Keystore properties should use nullable casts such as `as String?`.
- Core library desugaring is enabled.
- **`minSdk` is 26 since 1.6.0**, set explicitly in `defaultConfig` instead of
  `flutter.minSdkVersion` (24), because the ML Kit GenAI library requires API 26. This drops
  Android 7.0 and 7.1. `tools:overrideLibrary` with run-time guards was rejected: it risks
  class-verification crashes on API 24 and 25.
- **On-device AI dependencies are pinned exactly:** `com.google.mlkit:genai-prompt:1.0.0-beta4` (a
  beta API with no deprecation policy) and `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2`.
  Both build on the current toolchain (AGP 9.1.1, KGP 2.2.20, `builtInKotlin=false`).
- **R8 keep rules:** the release build type adds `proguardFiles("proguard-rules.pro")`.
  `android/app/proguard-rules.pro` keeps `com.google.mlkit.**`,
  `com.google.android.gms.internal.mlkit_**` and `kotlinx.coroutines.**`; without them a release
  build fails at run time in a way that looks like an unsupported device, while debug builds work.
- `AndroidManifest.xml` has `<package android:name="com.google.android.aicore"/>` in `<queries>`, so
  the AICore version is visible on API 30 and later.
- `GenAiChannel` (`android/app/src/main/kotlin/com/yuanzhe/my_anime/GenAiChannel.kt`) is attached in
  `MainActivity.configureFlutterEngine` next to the share and file-open channels and detached in
  `onDestroy`, which closes the AICore client. See [`on-device-ai.md`](on-device-ai.md).
- Signing is optional locally via `key.properties`; CI uses GitHub Secrets.
- `FileProvider` and `FLAG_ACTIVITY_NEW_TASK` support share/import flows (see
  [`features/share-and-import.md`](features/share-and-import.md)).

## Desktop API server, tray, and launch-at-startup

`local_api_server.dart` is a **desktop-only** Shelf server. It is disabled by default and
controlled from Settings.

- Default listen address: `localhost`.
- Default port: `7788`.
- Users may set `0.0.0.0` for LAN access.
- Non-loopback listening requires API credentials; an unsafe non-localhost startup without
  credentials is refused outright.
- CORS is permissive.
- When credentials **are** configured, HTTP Basic Auth is required for every non-`OPTIONS`
  request, **including loopback** — because permissive CORS would otherwise let any local web page
  read the API. Without credentials configured, loopback requests are allowed and non-loopback
  requests are rejected.

### Endpoints

| Endpoint | Notes |
| --- | --- |
| `GET /ping` | Health check |
| `POST /anime/search` | Calls `AnimeSearchService.searchAll()` — see [`features/multi-source-search.md`](features/multi-source-search.md) |
| `POST /anime/add` | Add an anime record |
| `GET /anime/list` | Returns `{total, counts, data}` |
| `GET /anime/unwatched` | Unwatched aired episodes |
| `GET /anime/history` | Returns `{total, counts, data}` |
| `GET /anime/ranking` | Rated anime, returns `{total, filters, sort, limit, data}` |

- Anime API item JSON includes the derived `status` (`completed`, `watching`, `dropped`, or
  `notStarted`), progress counts, URLs, cover path, notes, modified timestamp, and an optional
  rating summary, while preserving older fields for backward compatibility.
- `/anime/ranking` filters include all/quarter/year/range, anime type, rating field, sort order,
  and result limit.
- `/anime/ranking` also takes `scoreSource=personal|external` (default `personal`) and, with
  `external`, an optional `externalSource=<name>` to pin one database instead of averaging every
  source that scored the anime. Both are echoed back in `sort`. The default keeps every existing
  client's answer unchanged; `externalSource` without `scoreSource=external` is a `400`.
- Season filters include `current`, `YYYYQn`, `unassigned`, and `all`; `all` may sample returned
  rows while still keeping full counts accurate.
- API date serialization converts JST-derived episode dates to UTC strings with a trailing `Z`.

### Tray and startup

`tray_service.dart` handles desktop tray behavior: Show, Quit, minimize-to-tray, close-to-tray, and
macOS/Linux/Windows branches. `launch_at_startup` (the package) handles desktop auto-start.

## Connectivity detection

`connectivity_plus` (added in 1.5.0) gates the background metadata updater. It supports all four
target platforms and comes from the same `plus` family already in use (`share_plus`,
`package_info_plus`, `wakelock_plus`), so it needs no per-platform wiring beyond `pub get`. On
Android it merges its own `ACCESS_NETWORK_STATE` permission into the manifest.

**It reports the link type, not whether the link is metered.** This limit is real and worth stating
plainly, because the setting it drives is called "don't use cellular data":

- A device on a phone's Wi-Fi hotspot reports `wifi` while the uplink is cellular. Undetectable.
- A mobile VPN may report `vpn` and mask the underlying transport.
- Android exposes a correct answer through `NetworkCapabilities.NET_CAPABILITY_NOT_METERED`, but
  `connectivity_plus` does not surface it.

So the `noCellular` policy is a good heuristic, not a guarantee. A plugin failure is treated as
"allowed" rather than blocking the feature on a platform that cannot answer. See
[`features/metadata-auto-update.md`](features/metadata-auto-update.md).
