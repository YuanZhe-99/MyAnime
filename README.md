# MyAnime!!!!! — Your Anime Tracking Companion

A clean, privacy-first anime tracking app for Windows and Android.

## Features

- **Calendar View** — See which anime air each day and track unwatched episodes at a glance.
- **Seasonal Management** — Browse anime by season with search, filtering, and progress bars.
- **Multi-Source Search** *(full flavor only)* — Fetch titles, covers, episode counts, and summaries from bangumi.tv, MyAnimeList, acgsecrets.hk, and filmarks.com in one search.
- **Episode Tracking** — Mark episodes as watched / unwatched / skipped. Supports the late-night 25:00 JST format.
- **WebDAV Cloud Sync** — Sync data to your own cloud (e.g. Nextcloud) via WebDAV, with auto or manual sync.
- **Backup & Restore** — One-tap full backup (data + images). Optional auto-backup with retention policies.
- **Zip Export / Import** — Export all data as a `.zip` archive for easy migration or sharing.
- **Multi-Language** — English, Japanese, Simplified Chinese, Traditional Chinese.

## Build Flavors

| Flavor | Description | Online Search |
|--------|-------------|---------------|
| `full` | All features enabled — for direct distribution (GitHub Releases, desktop installer) | Yes |
| `store` | App Store / Google Play compliant — online search removed at compile time | No |

The flavor is controlled via `--dart-define=FLAVOR=store|full` (default: `full`).

## Platforms

| Platform | Artifact | Flavor |
|----------|----------|--------|
| Windows (x64)  | Inno Setup installer (`MyAnime_x.x.x_Setup.exe`) | full |
| Windows (ARM64) | Inno Setup installer (`MyAnime_x.x.x_arm64_Setup.exe`) | full |
| Android  | APK (`app-release.apk`) | full |
| Android  | AAB (`app-release.aab`) | store |
| iOS      | Sideload IPA | full |
| iOS      | App Store IPA | store |
| macOS    | DMG | full |

## Build

```bash
# ── Full flavor (direct distribution) ──

# Windows x64 installer
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss

# Windows ARM64 installer (requires Flutter master for ARM64 engine)
flutter build windows --release --dart-define=FLAVOR=full
iscc /DARM64 installer.iss

# Android APK
flutter build apk --release --dart-define=FLAVOR=full

# iOS Sideload (.app archive → install via AltStore / Sideloadly / etc.)
flutter build ios --release --no-codesign --dart-define=FLAVOR=full
# The .app is at build/ios/iphoneos/Runner.app
# To create an IPA:
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa && zip -r MyAnime_sideload.ipa Payload && cd -

# macOS DMG
flutter build macos --release --dart-define=FLAVOR=full
# Create a DMG (requires create-dmg):
create-dmg \
  --volname "MyAnime!!!!!" \
  --app-drop-link 400 150 \
  "build/macos/MyAnime.dmg" \
  "build/macos/Build/Products/Release/MyAnime!!!!!.app"

# ── Store flavor (App Store / Google Play) ──

# Android AAB
flutter build appbundle --release --dart-define=FLAVOR=store

# iOS App Store (requires signing & provisioning profile)
flutter build ipa --release --dart-define=FLAVOR=store
# Upload build/ios/ipa/*.ipa via Transporter or `xcrun altool`

# Windows (for testing only)
flutter build windows --release --dart-define=FLAVOR=store
```


## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
