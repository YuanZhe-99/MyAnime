# CI/CD and build commands

## Workflow

`.github/workflows/build.yml` runs on `v*` tag pushes and `workflow_dispatch`.

Every checkout step passes `submodules: recursive`. Without it `flutter pub get` fails on the missing
`packages/myapps_data` path dependency. The relative submodule URL resolves to the public GitHub copy
in CI, so the default `GITHUB_TOKEN` is sufficient.

## Jobs

- Android APK full flavor and AAB store flavor.
- Windows x64 full installer on `windows-latest`.
- Windows ARM64 full installer on `windows-11-arm`; this currently uses cached Flutter master because
  stable ARM64 engine support was not yet available when the workflow was written.
- iOS full sideload IPA without codesign.
- macOS full DMG via `create-dmg`.
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

`flutter analyze` currently reports pre-existing info-level items (in `tool/`, a view, and a test)
plus pub advisory decode warnings. Distinguish that pre-existing noise from regressions introduced by
the change in hand — compare against the count before your edit rather than expecting zero.

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

Prefer focused tests for production behavior, and keep tool scripts out of release-critical paths
unless the user asks for them.
