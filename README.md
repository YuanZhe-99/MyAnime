# MyAnime!!!!! — Your Anime Tracking Companion

A clean, privacy-first anime tracking app for Windows and Android.

## Features

- **Calendar View** — See which anime air each day and track unwatched episodes at a glance.
- **Seasonal Management** — Browse anime by season with search, filtering, and progress bars.
- **Multi-Source Search** — Fetch titles, covers, episode counts, and summaries from bangumi.tv, MyAnimeList, acgsecrets.hk, and filmarks.com in one search.
- **Episode Tracking** — Mark episodes as watched / unwatched / skipped. Supports the late-night 25:00 JST format.
- **WebDAV Cloud Sync** — Sync data to your own cloud (e.g. Nextcloud) via WebDAV, with auto or manual sync.
- **Backup & Restore** — One-tap full backup (data + images). Optional auto-backup with retention policies.
- **Zip Export / Import** — Export all data as a `.zip` archive for easy migration or sharing.
- **Multi-Language** — English, Japanese, Simplified Chinese, Traditional Chinese.

## Platforms

| Platform | Artifact |
|----------|----------|
| Windows  | Inno Setup installer (`MyAnime_x.x.x_Setup.exe`) |
| Android  | APK (`app-release.apk`) |

## Build

```bash
# Windows
flutter build windows --release
# then run Inno Setup on installer.iss

# Android
flutter build apk --release
```

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
