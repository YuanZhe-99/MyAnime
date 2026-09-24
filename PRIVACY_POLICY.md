# Privacy Policy

Thank you for using MyAnime!!!!!. We take your privacy seriously. This privacy policy explains how the app handles your data.

## Data Collection

MyAnime!!!!! does not collect, upload, or share any personal information. The app contains no analytics, advertising trackers, or data collection of any kind.

## Data Storage

All data you enter in the app — anime information, watch history, cover images, and settings — is stored locally on your device. You may change this to a custom path at any time (Desktop Version Only).

## Network Access

MyAnime!!!!! accesses the internet only in the following situations:

- **Searching for and refreshing anime information** *(full flavor only)*: When you actively search for anime, or refresh the database info on an anime you have already saved, the app sends requests to bangumi.tv, MyAnimeList (Jikan API), AniList (anilist.co), acgsecrets.hk, anime1.me and filmarks.com to retrieve publicly available anime information such as titles and alternate titles, summaries, cover art, episode counts, broadcast schedules, studios, genres, and those sites' public ratings. Only the search text or the saved source-page address is sent; none of your personal viewing data is included. **This feature is not included in versions distributed through the App Store or Google Play.**
- **Background database updates** *(full flavor only, since 1.5.0)*: While the app is open, it can also perform the requests described above **automatically**, without you pressing anything — refreshing the saved database info on anime you have already added, and looking up anime whose details are incomplete. The same sites, the same request contents, and the same limits apply: only a title or a saved source-page address is ever sent, and none of your personal viewing data is included. Any information found this way that would change one of your own fields is only *proposed*; nothing is written to your records until you confirm it. Since 1.5.7, for anime whose watch URL points at anime1.me, it also reads that site's public series list and the series page to record the newest episode the site lists; only the saved page address is sent.
- **Manual update checks** *(full flavor only, since 1.5.1)*: The "Available updates" screen has a **Check for updates** button that performs the same requests immediately, for as many of your anime as need checking. Because you asked for it explicitly, this one button works **even when background updates are switched off**, and it does not consult the Wi-Fi/cellular setting — it is the only way to check when background updates are off. It still refuses to run with no network connection, it shows its progress while it works, and you can stop it at any time. Nothing it finds is written to your records until you confirm it.
  - **On desktop this is on by default. On Android and iOS it defaults to "don't use cellular data"**, so a phone only does this work on Wi-Fi or a wired connection. Note that the app can only detect the *type* of connection, not whether it is billed — a phone hotspot, for example, still appears as Wi-Fi.
  - You can change this at any time, including turning it off entirely, in **Settings → Data → Background database updates**. A separate switch controls whether cover images are downloaded ahead of time; it is off by default.
- **WebDAV sync**: If you enable WebDAV cloud sync, the app sends your data to a WebDAV server that you configure yourself. The app does not send data to any other server.

No other network communication takes place.

## Third-Party Services

The full-featured version of the app uses the following third-party data sources for anime search:

- bangumi.tv
- MyAnimeList (via Jikan API)
- AniList (anilist.co)
- acgsecrets.hk
- anime1.me
- filmarks.com

These services have their own privacy policies, which we encourage you to review. MyAnime!!!!! only retrieves publicly available anime information and does not send any of your personal data to these services.

**Note:** Versions distributed through the App Store and Google Play (store flavor) do not include the online search feature and do not connect to these third-party services.

## On-Device AI (optional, since 1.6.0)

Automatic categories and recommendations can optionally use the language model built into your device — Gemini Nano through Android AICore, or the model that is part of Apple Intelligence on iOS 26 and macOS 26 or later. This is off by default and runs only after you turn on "Use on-device AI" in Settings.

- Everything the model does happens on your device. For categories it is given an anime's titles, format, year, studios and genres. For recommendation reasons it is also given the suggested titles, your ratings of a few recently finished anime, and which studios and categories you tend to like. Your notes are never given to it.

- On Android, the model is downloaded by the AICore system service from Google, and only when you tap Download in Settings. On Apple devices the model is part of Apple Intelligence and is managed by the system.

- Generated results stay on your device: they are neither synced nor backed up. No cloud model is used, including Apple's Private Cloud Compute.

## Data Backup

The app provides a local backup feature. Backup files are stored on your device and include all your anime data and cover images. The storage and management of backup files is entirely under your control.

## Changes to This Policy

This privacy policy may be updated from time to time. Updated versions will be published within the app or on the relevant distribution channels.
