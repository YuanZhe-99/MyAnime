# CI/CD and build commands

P2 uses shared navigation and measured content constraints; see [shared-ui.md](shared-ui.md).

Shared implementation ownership and fresh-clone instructions: [shared-ui.md](shared-ui.md).

## Workflow

`.github/workflows/build.yml` runs on `v*` tag pushes and `workflow_dispatch`.

Every checkout step passes `submodules: recursive`. Without it `flutter pub get` fails on the missing
`packages/myapps_data` path dependency. The relative submodule URL resolves to the public GitHub copy
in CI, so the default `GITHUB_TOKEN` is sufficient.

## Jobs

- Android APK full flavor and AAB store flavor. Both are release builds, so they run R8 with the
  ML Kit keep rules in `android/app/proguard-rules.pro`.
- Windows x64 full installer on `windows-latest`.
- Windows ARM64 full installer on `windows-11-arm`; this currently uses cached Flutter master because
  stable ARM64 engine support was not yet available when the workflow was written.
- iOS full sideload IPA without codesign. After `flutter build ios`, the step "Check
  FoundationModels is weakly linked (iOS)" runs `tool/check_weak_link.sh` on
  `build/ios/iphoneos/Runner.app`.
- macOS full DMG via `create-dmg`. After `flutter build macos`, the step "Check FoundationModels is
  weakly linked (macOS)" finds the `.app` under `build/macos/Build/Products/Release` (its name
  contains `!!!!!`, so it is found rather than typed, and always quoted) and runs the same script.
- GitHub Release artifact upload on tag push.

## Workflow caveats

- Keep the workflow Flutter version aligned with the Dart SDK constraint.
- GitHub `secrets` cannot be used directly in step `if` expressions; route them through job-level
  `env`.
- Windows ARM64 output is controlled by `iscc /DARM64 installer.iss`.
- The ARM64 Flutter master cache is weekly so Windows Defender reputation can accumulate for reused
  DLL hashes. Once stable Flutter ships suitable ARM64 support, switch this job back to a
  stable-channel setup.
- Remove the `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` compatibility macro once the
  dependency chain no longer includes `<experimental/coroutine>`.
- Action versions: `actions/checkout@v7`, `actions/setup-java@v5`, `actions/upload-artifact@v7`,
  `actions/download-artifact@v8`, `actions/cache@v6`, `softprops/action-gh-release@v3` (bumped from
  the Node 20-based majors GitHub deprecated). Validate workflow changes with a `workflow_dispatch`
  run before the next tag release.
- Known remaining warning: the Android job still prints Flutter's "plugins that apply KGP" warning
  for `flutter_timezone`, `package_info_plus`, `share_plus`, `shared_preferences_android`,
  `wakelock_plus`, and `file_picker`. The app side is already migrated (AGP 9.1.1, no app-level
  `kotlin-android`); the remaining warning is plugin-side only and, as of 2026-07, even the latest
  releases of those plugins still apply KGP. Full elimination requires flipping
  `android.builtInKotlin=true` once every plugin ships Built-in Kotlin support; verify with real
  APK/AAB builds when attempting it.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/anime_json_test.dart
flutter gen-l10n
flutter build apk --release --dart-define=FLAVOR=full
flutter build appbundle --release --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

Use the narrowest relevant command set for verification. For model or sync changes, include
`flutter test test/anime_json_test.dart`.

Since 1.7.0 `flutter analyze` reports **no issues** (the 25 pre-existing infos were cleared), so any finding
it prints is a regression introduced by the change in hand. Pub advisory decode warnings, when shown,
are unrelated noise.

## Fresh clone

The shared engine package is a git submodule, so a plain `git clone` leaves
`packages/myapps_data` empty and `flutter pub get` fails:

```bash
git clone --recurse-submodules <app-url>
# or, after a plain clone:
git submodule update --init
```

## `tool/` scripts

The `tool/` directory contains ad hoc scripts such as icon generation and search-source validation.
`tool/generate_ios_icons.dart` derives padded iOS default, dark, and tinted icon sources from
`assets/icon/app_icon.png` and writes preview PNGs under `/tmp`; after changing iOS icon sources,
regenerate `ios/Runner/Assets.xcassets/AppIcon.appiconset/` with `flutter_launcher_icons`.

`tool/gen_chinese_convert.dart` regenerates `lib/shared/utils/chinese_convert_data.dart` from the
OpenCC character dictionaries kept in `tool/data/opencc/` plus the legacy hand table in
`tool/data/legacy_st_pairs.txt`; it is offline and deterministic, so a re-run with unchanged inputs
produces no diff. Regenerate only when bumping OpenCC — refresh the two dictionary files from
`https://raw.githubusercontent.com/BYVoid/OpenCC/<commit>/data/dictionary/`, then run
`dart run tool/gen_chinese_convert.dart --commit <sha>` — and commit the data file.

`tool/check_weak_link.sh <path/to/App.app>` (1.6.0) is the one script CI runs. It walks every
Mach-O file in the bundle with `otool -l` and fails if any binary links FoundationModels with
`LC_LOAD_DYLIB` instead of `LC_LOAD_WEAK_DYLIB`, or if no binary links it at all (the
`myapps_ai_platform` plugin did not make it into the build). A strong link would stop the app
launching on iOS 18 and macOS 15 and earlier. It needs macOS (`otool`); quote the path. See
[`on-device-ai.md`](on-device-ai.md).

Prefer focused tests for production behavior, and keep tool scripts out of release-critical paths
unless the user asks for them.


## Playback verification (1.6.4)

Run flutter analyze and the anime_episode, anime_episode_storage, anime_player_ui, anime1_service, anime_json, bundle_import and detail-header tests. The opt-in command flutter test --dart-define=ANIME1_LIVE=true test/anime1_live_test.dart verifies real directory pagination and media byte access without printing credentials. This is not visual or audio playback verification. Build full/store variants on their platform hosts; missing host validation must be reported explicitly. Windows ARM64 must not ship x64 media DLLs.

Implementation verification on Windows ARM64: Android full debug APK and Windows ARM64 full release builds passed. The focused regression suite, native-player lifecycle tests and store-route network gate passed; live public-directory/media-byte verification passed separately. Analysis reports only existing info-level lints. The initial v1.6.4 CI run passed Windows x64/ARM64 installers, iOS sideload IPA and Android full APK/store AAB. macOS failed on the WebView protocol availability error described in platform notes; the repaired commit then passed a manual Build All Platforms run on all five platforms, including the macOS build and FoundationModels weak-link check, before the tag was moved to it. Device video/audio/fullscreen acceptance remains unverified. The installed ARM64 Flutter SDK selects the Windows host architecture and exposes no cross-build target option; Apple builds require an Apple host. A successful build is not device playback acceptance.
