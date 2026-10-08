import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';

class PrivacyPolicyPage extends StatelessWidget {
  /// Purpose: Create a privacy policy page instance.
  /// Inputs: None.
  /// Returns: A new `PrivacyPolicyPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const PrivacyPolicyPage({super.key});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final text =
        '${_getText(locale)}\n\n${l10n.webdavPrivacyPlaintext}\n${l10n.webdavPrivacyHttp}\n${l10n.webdavPrivacyPaused}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyPolicy)),
      body: SingleChildScrollView(
        padding: navBarAwarePadding(context, const EdgeInsets.all(16)),
        child: SelectableText(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  /// Purpose: Provide the internal get text helper for this file.
  /// Inputs: `locale`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _getText(Locale locale) {
    if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
      return _zhTW;
    }
    switch (locale.languageCode) {
      case 'zh':
        return _zh;
      case 'ja':
        return _ja;
      default:
        return _en;
    }
  }

  static const _en = '''Privacy Policy

Thank you for using MyAnime!!!!!. We take your privacy seriously. This privacy policy explains how the app handles your data.

Data Collection

MyAnime!!!!! contains no analytics or advertising trackers. User-configured WebDAV sync and explicitly selected online AI send the data described below to the chosen server.

Data Storage

All data you enter in the app — anime information, watch history, cover images, and settings — is stored locally on your device. You may change this to a custom path at any time (Desktop Version Only).

Network Access

MyAnime!!!!! accesses the internet only in the following situations:

• Searching for and refreshing anime information (full version only): When you actively search for anime, or refresh the database info on an anime you have already saved, the app sends requests to bangumi.tv, MyAnimeList (Jikan API), AniList (anilist.co), acgsecrets.hk, anime1.me and filmarks.com to retrieve publicly available anime information such as titles and alternate titles, summaries, cover art, episode counts, broadcast schedules, studios, genres, and those sites' public ratings. Only the search text or the saved source-page address is sent; none of your personal viewing data is included. This feature is not included in versions distributed through the App Store or Google Play.

• Background database updates (full version only, since 1.5.0): While the app is open, it can also perform the requests described above automatically, without you pressing anything — refreshing the saved database info on anime you have already added, and looking up anime whose details are incomplete. The same sites, the same request contents, and the same limits apply: only a title or a saved source-page address is ever sent, and none of your personal viewing data is included. Any information found this way that would change one of your own fields is only proposed; nothing is written to your records until you confirm it. Since 1.5.7, for anime whose watch URL points at anime1.me, it also reads that site's public series list and the series page to record the newest episode the site lists; only the saved page address is sent.

• Covers and summaries of missing sequels (full version only, since 1.6.3): When the databases list a sequel you have not added yet, the app fetches that sequel's public page from the same database (AniList, MyAnimeList or bangumi.tv) and downloads its cover art, to show a small cover and a short summary on the "Not in your library yet" card. Only the sequel's public page address is sent. The small cover and summary are stored in your recommendations file, which syncs to your own WebDAV server if you set one up, and are deleted when you mark the card Not interested.

• Manual update checks (full version only, since 1.5.1): The "Available updates" screen has a Check for updates button that performs the same requests immediately, for as many of your anime as need checking. Because you asked for it explicitly, this one button works even when background updates are switched off, and it does not consult the Wi-Fi/cellular setting — it is the only way to check when background updates are off. It still refuses to run with no network connection, it shows its progress while it works, and you can stop it at any time. Nothing it finds is written to your records until you confirm it.

On desktop this is on by default. On Android and iOS it defaults to "don't use cellular data", so a phone only does this work on Wi-Fi or a wired connection. Note that the app can only detect the type of connection, not whether it is billed — a phone hotspot, for example, still appears as Wi-Fi. You can change this at any time, including turning it off entirely, in Settings → Data → Background database updates. A separate switch controls whether cover images are downloaded ahead of time; it is off by default.

• Anime1 episode playback (full version, since 1.6.4): Opening an anime detail page can fetch its public episode directory. Playing an episode contacts Anime1 and its video hosts (v.anime1.me and subdomains) with the page address and temporary playback credentials. Native credentials stay in memory and are not synced or backed up. The embedded website may load its own third-party resources and keep cookies in the local WebView profile; that profile is not part of app sync or backups. Personal ratings, notes and watch history are not sent.

• WebDAV sync: If you enable WebDAV cloud sync, the app sends your data to a WebDAV server that you configure yourself. The app does not send data to any other server.

The optional local-model downloads and online AI requests described below also use the network.

Third-Party Services

The app uses the following third-party data sources for anime search:

• bangumi.tv
• MyAnimeList (via Jikan API)
• acgsecrets.hk
• anime1.me
• filmarks.com

These services have their own privacy policies, which we encourage you to review. MyAnime!!!!! only retrieves publicly available anime information and does not send any of your personal data to these services.

Note: Versions distributed through the App Store and Google Play do not include the online search feature and do not connect to these third-party services.

AI Features (optional, since 1.6.0)

Automatic categories and short reasons for recommendations can optionally be written by an AI source. This is off by default and runs only after you turn on "Use AI features" in Settings and choose a source under "AI source and model". The app never switches to an online source by itself: "Automatic (system AI)" uses only the AI built into your system.

What a source is given: for categories, an anime's titles, format, year, type, episode count, studios and genres. For recommendation reasons, also the suggested titles, your ratings of a few recently finished anime, and which studios and categories you tend to like. Your notes and watch history are never given to it.

• System AI (since 1.6.0): Gemini Nano through Android AICore, or the model that is part of Apple Intelligence on iOS 26 and macOS 26 or later. It runs on your device. On Android, AICore downloads the model from Google, and only when you tap Download in Settings; on Apple devices the model is managed by the system. Apple's Private Cloud Compute is never used.

• Local models (since 1.8.11): Qwen3.5 0.8B or 2B, or Gemma 4 E2B (4-bit), downloaded from Hugging Face only when you tap Download; since 1.9.0 also a GGUF model you choose from a Hugging Face repository, after a warning that it is unverified. Listing a repository, reading the start of a file and downloading reveal your IP address to Hugging Face but send none of your app data. The files are checked against a pinned SHA-256, stay on this device, and are excluded from sync, backups and ZIP exports. They run on your device's processor, on its GPU only if you turn that on; no prompt leaves the device.

• Online sources (since 1.8.11): providers you add yourself, with a server address and API key you enter. Only while you have selected one, and only after you accept its privacy notice for that server on this device, the prompts described above are sent to that provider, which handles them under its own privacy policy. An online source is never used as a fallback. API keys are stored as plaintext on this device only and are excluded from sync, backups and ZIP exports. Connections to an http:// address are not encrypted.

Where results are kept: AI categories are cached on this device only; they are neither synced nor backed up. Reasons on the Recommendations page are kept in memory only. Reasons on a detail page's Related list are saved with that list in your recommendations file, which syncs to your own WebDAV server if you set one up and is included in backups. Each result is labelled with where it was generated: on this device, or online with the provider's name.

Data Backup

The app provides a local backup feature. Backup files are stored on your device and include all your anime data and cover images. The storage and management of backup files is entirely under your control.

Changes to This Policy

This privacy policy may be updated from time to time. Updated versions will be published within the app or on the relevant distribution channels.''';

  static const _zh = '''隐私政策

感谢您使用 MyAnime!!!!!。我们非常重视您的隐私。本隐私政策说明了应用如何处理您的数据。

数据收集

MyAnime!!!!! 不包含分析工具或广告追踪器。用户配置的 WebDAV 同步和明确选择的在线 AI 会向所选服务器发送下文说明的数据。

数据存储

您在应用中输入的所有数据——番剧信息、观看记录、封面图片和设置——均存储在您的设备本地。您可以随时更改存储路径（仅桌面版）。

网络访问

MyAnime!!!!! 仅在以下情况下访问互联网：

• 搜索与刷新番剧信息（完整版专有）：当您主动搜索番剧，或刷新已保存番剧的资料库信息时，应用会向 bangumi.tv、MyAnimeList（Jikan API）、AniList（anilist.co）、acgsecrets.hk、anime1.me 和 filmarks.com 发送请求，以获取公开的番剧信息，如标题与别名、简介、封面、集数、放送排期、制作公司、类型标签，以及这些站点的公开评分。发送的只有搜索文本或已保存的来源页面地址，不包含您的任何个人观看数据。通过 App Store 或 Google Play 分发的版本不包含此功能。

• 后台更新资料库信息（完整版专有，1.5.0 起）：在应用打开期间，它还可以在您不点击任何按钮的情况下自动执行上述请求——为您已添加的番剧刷新已保存的资料库信息，并为资料不全的番剧查找在线资料。站点、请求内容与限制完全相同：发送的始终只有一个标题或已保存的来源页面地址，不包含您的任何个人观看数据。以这种方式找到的、会改动您自己字段的信息只会被"建议"；在您确认之前，不会有任何内容被写入您的记录。自 1.5.7 起，对于观看链接指向 anime1.me 的番剧，它还会读取该站点的公开作品列表与作品页面，以记录站点已更新到第几集；发送的只有已保存的页面地址。

• 缺失续作的封面与简介（完整版专有，1.6.3 起）：当资料库列出一部您还没有添加的续作时，应用会从同一资料库（AniList、MyAnimeList 或 bangumi.tv）获取该续作的公开页面并下载其封面，以便在「番剧库里还没有」卡片上显示小封面和简短简介。发送的只有该续作的公开页面地址。小封面和简介保存在您的推荐文件中；如果您设置了 WebDAV，该文件会同步到您自己的服务器。将卡片标记为「不感兴趣」时，它们会被删除。

• 手动检查更新（完整版专有，1.5.1 起）：「可用更新」页面上有一个「检查更新」按钮，会立即对您所有需要检查的番剧执行上述相同的请求。由于这是您明确要求的操作，这一个按钮在**后台自动更新已关闭时同样有效**，也不受 Wi-Fi/蜂窝设置的限制——在后台更新关闭时，它是唯一的检查途径。没有网络连接时它仍会拒绝执行；执行期间会显示进度，您可以随时停止。它找到的任何内容在您确认之前都不会写入您的记录。

桌面端默认开启。Android 与 iOS 默认为"不使用蜂窝数据"，因此手机只会在 Wi-Fi 或有线连接下进行这项工作。请注意，应用只能识别连接的类型，无法判断它是否计费——例如手机热点同样会被识别为 Wi-Fi。您可以随时在"设置 → 数据 → 后台更新资料库信息"中更改此项，包括完全关闭。另有一个独立开关控制是否提前下载封面图，该开关默认关闭。

• Anime1 分集播放（完整版，1.6.4 起）：打开番剧详情时可读取公开分集目录。播放时会向 Anime1 及其视频主机（v.anime1.me 及子域名）发送页面地址和临时播放凭据。原生播放凭据仅保存在内存中，不参与同步或备份。内嵌网站可能加载其第三方资源，并在本地 WebView 配置中保存 Cookie；该配置不进入应用同步或备份。不会发送个人评分、笔记或观看记录。

• WebDAV 同步：如果您启用了 WebDAV 云同步，应用会将您的数据发送到您自行配置的 WebDAV 服务器。应用不会向其他任何服务器发送数据。

除此之外不进行任何网络通信。

第三方服务

应用使用以下第三方数据源进行番剧搜索：

• bangumi.tv
• MyAnimeList（通过 Jikan API）
• acgsecrets.hk
• anime1.me
• filmarks.com

这些服务有各自的隐私政策，建议您查阅。MyAnime!!!!! 仅获取公开的番剧信息，不会向这些服务发送任何个人数据。

注意：通过 App Store 和 Google Play 分发的版本不包含在线搜索功能，不会连接到上述第三方服务。

AI 功能（可选，1.6.0 起）

自动分类与推荐的简短理由可以选择由某个 AI 来源生成。此功能默认关闭，只有在您于设置中开启"使用 AI 功能"并在"AI 来源与模型"中选择来源后才会运行。应用绝不会自行切换到在线来源："自动（系统 AI）"只使用系统内置的 AI。

来源会收到的内容：分类时为番剧的标题、格式、年份、类型、集数、制作公司和类型标签。写推荐理由时，还有推荐的标题、您对最近看完的几部番剧的评分，以及您偏好的制作公司和分类。您的备注和观看记录永远不会提供给它。

• 系统 AI（1.6.0 起）：Android 上通过 AICore 使用 Gemini Nano，iOS 26 与 macOS 26 及以上使用 Apple Intelligence 自带的模型。在您的设备上运行。在 Android 上，模型由 AICore 从 Google 下载，且仅在您于设置中点击"下载"时进行；在 Apple 设备上，模型由系统管理。绝不使用 Apple 的 Private Cloud Compute。

• 本地模型（1.8.11 起）：Qwen3.5 0.8B 或 2B，或 Gemma 4 E2B（4 位），仅在您点击"下载"时从 Hugging Face 下载；自 1.9.0 起，也可以在确认“未经验证”警告后从 Hugging Face 仓库选择一个 GGUF 模型。列出仓库、读取文件开头和下载时，Hugging Face 会获知您的 IP 地址，但不发送任何应用数据。文件会按固定的 SHA-256 校验，只保存在本设备上，不参与同步、备份和 ZIP 导出。模型在您设备的处理器上运行，只有您开启时才使用 GPU，提示不会离开设备。

• 在线来源（1.8.11 起）：由您自己添加的服务商，服务器地址和 API Key 均由您填写。只有在您选中某个在线来源，并在本设备上接受该服务器的隐私提醒之后，上述提示才会发送给该服务商，由其按自身的隐私政策处理。在线来源绝不会作为后备自动使用。API Key 以明文只保存在本设备上，不参与同步、备份和 ZIP 导出。连接 http:// 地址时不加密。

结果保存在哪里：AI 分类只缓存在本设备上，既不同步也不备份。推荐页上的理由只保存在内存中。详情页"相关推荐"列表中的理由随该列表保存在推荐文件中；如果您设置了 WebDAV，该文件会同步到您自己的服务器，并包含在备份中。每条结果都会标注生成位置：本设备，或写明服务商名称的在线来源。

数据备份

应用提供本地备份功能。备份文件存储在您的设备上，包含您的所有番剧数据和封面图片。备份文件的存储和管理完全由您掌控。

政策变更

本隐私政策可能会不时更新。更新版本将在应用内或相关分发渠道发布。''';

  static const _zhTW = '''隱私政策

感謝您使用 MyAnime!!!!!。我們非常重視您的隱私。本隱私政策說明了應用程式如何處理您的資料。

資料收集

MyAnime!!!!! 不包含分析工具或廣告追蹤器。使用者設定的 WebDAV 同步和明確選擇的線上 AI 會向所選伺服器傳送下文說明的資料。

資料儲存

您在應用程式中輸入的所有資料——番劇資訊、觀看紀錄、封面圖片和設定——均儲存在您的裝置本機。您可以隨時更改儲存路徑（僅桌面版）。

網路存取

MyAnime!!!!! 僅在以下情況下存取網際網路：

• 搜尋番劇資訊（完整版專有）：當您主動搜尋番劇時，應用程式會向 bangumi.tv、MyAnimeList（Jikan API）、acgsecrets.hk、anime1.me 和 filmarks.com 傳送請求，以取得公開的番劇資訊，如標題、簡介、封面和集數。透過 App Store 或 Google Play 分發的版本不包含此功能。自 1.5.7 起，對於觀看連結指向 anime1.me 的番劇，應用程式也會在背景讀取該站點的公開作品列表與作品頁面，以記錄站點已更新到第幾集；傳送的只有已儲存的頁面位址。

• 缺失續作的封面與簡介（完整版專有，1.6.3 起）：當資料庫列出一部您還沒有新增的續作時，應用程式會從同一資料庫（AniList、MyAnimeList 或 bangumi.tv）取得該續作的公開頁面並下載其封面，以便在「番劇庫裡還沒有」卡片上顯示小封面與簡短簡介。傳送的只有該續作的公開頁面位址。小封面與簡介儲存在您的推薦檔案中；如果您設定了 WebDAV，該檔案會同步到您自己的伺服器。將卡片標記為「不感興趣」時，它們會被刪除。

• Anime1 分集播放（完整版，1.6.4 起）：開啟番劇詳情時可讀取公開分集目錄。播放時會向 Anime1 及其影片主機（v.anime1.me 及子網域）傳送頁面位址和暫時播放憑證。原生播放憑證僅保存在記憶體中，不參與同步或備份。內嵌網站可能載入其第三方資源，並在本機 WebView 設定中儲存 Cookie；該設定不進入應用程式同步或備份。不會傳送個人評分、筆記或觀看紀錄。

• WebDAV 同步：如果您啟用了 WebDAV 雲端同步，應用程式會將您的資料傳送到您自行設定的 WebDAV 伺服器。應用程式不會向其他任何伺服器傳送資料。

除此之外不進行任何網路通訊。

第三方服務

應用程式使用以下第三方資料來源進行番劇搜尋：

• bangumi.tv
• MyAnimeList（透過 Jikan API）
• acgsecrets.hk
• anime1.me
• filmarks.com

這些服務有各自的隱私政策，建議您查閱。MyAnime!!!!! 僅取得公開的番劇資訊，不會向這些服務傳送任何個人資料。

注意：透過 App Store 和 Google Play 分發的版本不包含線上搜尋功能，不會連線到上述第三方服務。

AI 功能（可選，1.6.0 起）

自動分類與推薦的簡短理由可以選擇由某個 AI 來源產生。此功能預設關閉，只有在您於設定中開啟「使用 AI 功能」並在「AI 來源與模型」中選擇來源後才會執行。應用程式絕不會自行切換到線上來源：「自動（系統 AI）」只使用系統內建的 AI。

來源會收到的內容：分類時為番劇的標題、格式、年份、類型、集數、製作公司和類型標籤。撰寫推薦理由時，還有推薦的標題、您對最近看完的幾部番劇的評分，以及您偏好的製作公司和分類。您的備註和觀看紀錄永遠不會提供給它。

• 系統 AI（1.6.0 起）：Android 上透過 AICore 使用 Gemini Nano，iOS 26 與 macOS 26 及以上使用 Apple Intelligence 內建的模型。在您的裝置上執行。在 Android 上，模型由 AICore 從 Google 下載，且僅在您於設定中點選「下載」時進行；在 Apple 裝置上，模型由系統管理。絕不使用 Apple 的 Private Cloud Compute。

• 本機模型（1.8.11 起）：Qwen3.5 0.8B 或 2B，或 Gemma 4 E2B（4 位元），僅在您點選「下載」時從 Hugging Face 下載；自 1.9.0 起，也可以在確認「未經驗證」警告後從 Hugging Face 儲存庫選擇一個 GGUF 模型。列出儲存庫、讀取檔案開頭和下載時，Hugging Face 會得知您的 IP 位址，但不傳送任何應用程式資料。檔案會依固定的 SHA-256 驗證，只儲存在本裝置上，不參與同步、備份和 ZIP 匯出。模型在您裝置的處理器上執行，只有您開啟時才使用 GPU，提示不會離開裝置。

• 線上來源（1.8.11 起）：由您自行新增的服務商，伺服器位址和 API Key 均由您填寫。只有在您選中某個線上來源，並在本裝置上接受該伺服器的隱私提醒之後，上述提示才會傳送給該服務商，由其依自身的隱私政策處理。線上來源絕不會作為備援自動使用。API Key 以明文只儲存在本裝置上，不參與同步、備份和 ZIP 匯出。連線至 http:// 位址時不加密。

結果儲存在哪裡：AI 分類只快取在本裝置上，既不同步也不備份。推薦頁上的理由只保存在記憶體中。詳情頁「相關推薦」清單中的理由隨該清單儲存在推薦檔案中；如果您設定了 WebDAV，該檔案會同步到您自己的伺服器，並包含在備份中。每條結果都會標註產生位置：本裝置，或寫明服務商名稱的線上來源。

資料備份

應用程式提供本機備份功能。備份檔案儲存在您的裝置上，包含您的所有番劇資料和封面圖片。備份檔案的儲存和管理完全由您掌控。

政策變更

本隱私政策可能會不時更新。更新版本將在應用程式內或相關分發管道發布。''';

  static const _ja = '''プライバシーポリシー

MyAnime!!!!! をご利用いただきありがとうございます。私たちはお客様のプライバシーを重視しています。このプライバシーポリシーは、アプリがお客様のデータをどのように取り扱うかを説明します。

データ収集

MyAnime!!!!! にアナリティクスや広告トラッカーはありません。設定した WebDAV 同期と明示的に選んだオンライン AI は、以下に記載するデータを選択したサーバーへ送ります。

データ保存

アプリに入力されたすべてのデータ（アニメ情報、視聴履歴、カバー画像、設定）は、お客様のデバイスにローカルで保存されます。保存先はいつでも変更できます（デスクトップ版のみ）。

ネットワークアクセス

MyAnime!!!!! は以下の場合にのみインターネットにアクセスします：

• アニメ情報の検索と更新（完全版のみ）：お客様がアニメを検索した際、または保存済みアニメのデータベース情報を更新した際、アプリは bangumi.tv、MyAnimeList（Jikan API）、AniList（anilist.co）、acgsecrets.hk、anime1.me、filmarks.com にリクエストを送信し、タイトルおよび別名、あらすじ、カバー画像、話数、放送スケジュール、制作会社、ジャンル、各サイトの公開評価などの公開情報を取得します。送信されるのは検索文字列または保存済みのソースページのアドレスのみで、お客様の視聴データは一切含まれません。App Store または Google Play で配信されるバージョンにはこの機能は含まれていません。

• バックグラウンドでのデータベース情報の更新（完全版のみ、1.5.0 以降）：アプリの起動中、上記のリクエストを、お客様が何も操作しなくても自動的に実行することがあります。すでに追加済みのアニメについては保存されたデータベース情報を更新し、情報が不足しているアニメについては検索を行います。送信先のサイト、リクエストの内容、制限はいずれも同じです。送信されるのはタイトルまたは保存済みのソースページのアドレスのみで、お客様の視聴データは一切含まれません。この方法で見つかった情報のうち、お客様ご自身の項目を変更するものは「提案」されるだけであり、お客様が確認するまで記録に書き込まれることはありません。1.5.7 以降は、視聴URLが anime1.me を指すアニメについて、同サイトの公開作品リストと作品ページも読み取り、サイトが公開している最新話を記録します。送信されるのは保存済みのページアドレスのみです。

• ライブラリにない続編のカバーとあらすじ（完全版のみ、1.6.3 以降）：まだ追加していない続編がデータベースに掲載されている場合、アプリは同じデータベース（AniList、MyAnimeList または bangumi.tv）からその続編の公開ページを取得し、カバー画像をダウンロードして、「まだライブラリにありません」カードに小さなカバーと短いあらすじを表示します。送信されるのは続編の公開ページのアドレスのみです。小さなカバーとあらすじはおすすめファイルに保存され、WebDAV を設定している場合はお客様ご自身のサーバーに同期されます。カードを「興味なし」にすると削除されます。

• 手動での更新確認（完全版のみ、1.5.1 以降）：「利用できる更新」画面には「更新を確認」ボタンがあり、確認が必要なアニメすべてに対して上記と同じリクエストを直ちに実行します。お客様が明示的に指示した操作であるため、このボタンはバックグラウンド更新をオフにしていても動作し、Wi-Fi/モバイル通信の設定も参照しません。バックグラウンド更新がオフのとき、これが唯一の確認手段だからです。ネットワークに接続されていない場合は実行を拒否します。実行中は進捗が表示され、いつでも停止できます。見つかった内容は、お客様が確認するまで記録に書き込まれることはありません。

デスクトップでは既定でオンです。Android と iOS では既定で「モバイルデータを使わない」に設定されており、スマートフォンは Wi-Fi または有線接続の場合にのみこの処理を行います。なお、アプリが判別できるのは接続の種類のみで、従量制かどうかは分かりません。たとえばスマートフォンのテザリングも Wi-Fi として認識されます。この設定は「設定 → データ → バックグラウンドでデータベース情報を更新」からいつでも変更でき、完全にオフにすることもできます。カバー画像を事前にダウンロードするかどうかは別のスイッチで制御され、既定ではオフです。

• Anime1 各話再生（完全版、1.6.4 以降）：詳細画面を開くと公開各話一覧を取得する場合があります。再生時は Anime1 と動画ホスト（v.anime1.me およびサブドメイン）へページ URL と一時的な再生認証情報を送信します。ネイティブ再生の認証情報はメモリ内のみで、同期・バックアップしません。内蔵 Web サイトは第三者のリソースを読み込み、ローカル WebView に Cookie を保存する場合があります。このプロファイルは同期・バックアップ対象外です。個人の評価、メモ、視聴履歴は送信しません。

• WebDAV同期：WebDAVクラウド同期を有効にした場合、アプリはお客様が設定したWebDAVサーバーにデータを送信します。それ以外のサーバーにデータを送信することはありません。

上記以外のネットワーク通信は行われません。

サードパーティサービス

アプリはアニメ検索に以下のサードパーティデータソースを使用しています：

• bangumi.tv
• MyAnimeList（Jikan API経由）
• acgsecrets.hk
• anime1.me
• filmarks.com

これらのサービスには独自のプライバシーポリシーがあります。ご確認をお勧めします。MyAnime!!!!! は公開されているアニメ情報のみを取得し、お客様の個人データをこれらのサービスに送信することはありません。

注意：App Store および Google Play で配信されるバージョンにはオンライン検索機能は含まれておらず、上記のサードパーティサービスに接続しません。

AI機能（任意、1.6.0 以降）

自動分類とおすすめの短い理由は、任意で AI ソースに書かせることができます。初期状態ではオフで、設定で「AI機能を使う」をオンにし、「AI のソースとモデル」でソースを選んだ場合にのみ動作します。アプリが自分からオンラインソースに切り替えることはありません。「自動（システム AI）」はシステム内蔵の AI だけを使います。

ソースに渡す内容：分類では、作品のタイトル、形式、年、種類、話数、制作会社、ジャンル。おすすめの理由では、それに加えておすすめ作品のタイトル、最近見終えた数作品へのあなたの評価、よく好む制作会社と分類。メモと視聴履歴は渡しません。

• システムAI（1.6.0 以降）：Android では AICore 経由の Gemini Nano、iOS 26・macOS 26 以降では Apple Intelligence のモデル。端末内で動作します。Android ではモデルを AICore が Google からダウンロードし、それは設定で「ダウンロード」をタップしたときだけです。Apple 製デバイスではシステムがモデルを管理します。Apple の Private Cloud Compute は使いません。

• ローカルモデル（1.8.11 以降）：Qwen3.5 0.8B・2B、または Gemma 4 E2B（4bit）。「ダウンロード」をタップしたときだけ Hugging Face からダウンロードします。1.9.0 以降は、未検証である旨の警告を確認したうえで、Hugging Face のリポジトリから GGUF モデルを選ぶこともできます。リポジトリの一覧表示、ファイル冒頭の読み取り、ダウンロードにより IP アドレスが Hugging Face に伝わりますが、アプリのデータは送りません。ファイルは固定の SHA-256 で検証され、この端末にのみ保存され、同期・バックアップ・ZIP エクスポートの対象外です。端末のプロセッサで動作し、GPU はオンにした場合だけ使います。プロンプトは端末の外に出ません。

• オンラインソース（1.8.11 以降）：あなたが自分で追加する提供元で、サーバーのアドレスと API キーはあなたが入力します。それを選択している間だけ、かつこの端末でそのサーバーのプライバシー通知を承認した後にだけ、上記のプロンプトがその提供元に送られ、提供元自身のプライバシーポリシーに従って扱われます。オンラインソースが代替として自動的に使われることはありません。API キーは平文でこの端末にのみ保存され、同期・バックアップ・ZIP エクスポートの対象外です。http:// のアドレスへの接続は暗号化されません。

結果の保存先：AI の分類はこの端末にのみキャッシュされ、同期もバックアップもされません。おすすめページの理由はメモリ上にのみ保持されます。詳細ページの「関連」リストの理由はそのリストと一緒におすすめファイルに保存され、WebDAV を設定していればあなたのサーバーと同期され、バックアップにも含まれます。各結果には生成場所が表示されます：この端末、またはオンラインの提供元の名前。

データバックアップ

アプリはローカルバックアップ機能を提供しています。バックアップファイルはお客様のデバイスに保存され、すべてのアニメデータとカバー画像が含まれます。バックアップファイルの保存と管理は完全にお客様の管理下にあります。

ポリシーの変更

このプライバシーポリシーは随時更新される場合があります。更新版はアプリ内または関連する配信チャネルで公開されます。''';
}
