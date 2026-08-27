import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

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
    final text = _getText(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyPolicy)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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

MyAnime!!!!! does not collect, upload, or share any personal information. The app contains no analytics, advertising trackers, or data collection of any kind.

Data Storage

All data you enter in the app — anime information, watch history, cover images, and settings — is stored locally on your device. You may change this to a custom path at any time (Desktop Version Only).

Network Access

MyAnime!!!!! accesses the internet only in the following situations:

• Searching for and refreshing anime information (full version only): When you actively search for anime, or refresh the database info on an anime you have already saved, the app sends requests to bangumi.tv, MyAnimeList (Jikan API), AniList (anilist.co), acgsecrets.hk, anime1.me and filmarks.com to retrieve publicly available anime information such as titles and alternate titles, summaries, cover art, episode counts, broadcast schedules, studios, genres, and those sites' public ratings. Only the search text or the saved source-page address is sent; none of your personal viewing data is included. This feature is not included in versions distributed through the App Store or Google Play.

• Background database updates (full version only, since 1.5.0): While the app is open, it can also perform the requests described above automatically, without you pressing anything — refreshing the saved database info on anime you have already added, and looking up anime whose details are incomplete. The same sites, the same request contents, and the same limits apply: only a title or a saved source-page address is ever sent, and none of your personal viewing data is included. Any information found this way that would change one of your own fields is only proposed; nothing is written to your records until you confirm it.

• Manual update checks (full version only, since 1.5.1): The "Available updates" screen has a Check for updates button that performs the same requests immediately, for as many of your anime as need checking. Because you asked for it explicitly, this one button works even when background updates are switched off, and it does not consult the Wi-Fi/cellular setting — it is the only way to check when background updates are off. It still refuses to run with no network connection, it shows its progress while it works, and you can stop it at any time. Nothing it finds is written to your records until you confirm it.

On desktop this is on by default. On Android and iOS it defaults to "don't use cellular data", so a phone only does this work on Wi-Fi or a wired connection. Note that the app can only detect the type of connection, not whether it is billed — a phone hotspot, for example, still appears as Wi-Fi. You can change this at any time, including turning it off entirely, in Settings → Data → Background database updates. A separate switch controls whether cover images are downloaded ahead of time; it is off by default.

• WebDAV sync: If you enable WebDAV cloud sync, the app sends your data to a WebDAV server that you configure yourself. The app does not send data to any other server.

No other network communication takes place.

Third-Party Services

The app uses the following third-party data sources for anime search:

• bangumi.tv
• MyAnimeList (via Jikan API)
• acgsecrets.hk
• anime1.me
• filmarks.com

These services have their own privacy policies, which we encourage you to review. MyAnime!!!!! only retrieves publicly available anime information and does not send any of your personal data to these services.

Note: Versions distributed through the App Store and Google Play do not include the online search feature and do not connect to these third-party services.

Data Backup

The app provides a local backup feature. Backup files are stored on your device and include all your anime data and cover images. The storage and management of backup files is entirely under your control.

Changes to This Policy

This privacy policy may be updated from time to time. Updated versions will be published within the app or on the relevant distribution channels.''';

  static const _zh = '''隐私政策

感谢您使用 MyAnime!!!!!。我们非常重视您的隐私。本隐私政策说明了应用如何处理您的数据。

数据收集

MyAnime!!!!! 不收集、上传或共享任何个人信息。应用不包含任何分析工具、广告追踪器或数据收集功能。

数据存储

您在应用中输入的所有数据——番剧信息、观看记录、封面图片和设置——均存储在您的设备本地。您可以随时更改存储路径（仅桌面版）。

网络访问

MyAnime!!!!! 仅在以下情况下访问互联网：

• 搜索与刷新番剧信息（完整版专有）：当您主动搜索番剧，或刷新已保存番剧的资料库信息时，应用会向 bangumi.tv、MyAnimeList（Jikan API）、AniList（anilist.co）、acgsecrets.hk、anime1.me 和 filmarks.com 发送请求，以获取公开的番剧信息，如标题与别名、简介、封面、集数、放送排期、制作公司、类型标签，以及这些站点的公开评分。发送的只有搜索文本或已保存的来源页面地址，不包含您的任何个人观看数据。通过 App Store 或 Google Play 分发的版本不包含此功能。

• 后台更新资料库信息（完整版专有，1.5.0 起）：在应用打开期间，它还可以在您不点击任何按钮的情况下自动执行上述请求——为您已添加的番剧刷新已保存的资料库信息，并为资料不全的番剧查找在线资料。站点、请求内容与限制完全相同：发送的始终只有一个标题或已保存的来源页面地址，不包含您的任何个人观看数据。以这种方式找到的、会改动您自己字段的信息只会被"建议"；在您确认之前，不会有任何内容被写入您的记录。

• 手动检查更新（完整版专有，1.5.1 起）：「可用更新」页面上有一个「检查更新」按钮，会立即对您所有需要检查的番剧执行上述相同的请求。由于这是您明确要求的操作，这一个按钮在**后台自动更新已关闭时同样有效**，也不受 Wi-Fi/蜂窝设置的限制——在后台更新关闭时，它是唯一的检查途径。没有网络连接时它仍会拒绝执行；执行期间会显示进度，您可以随时停止。它找到的任何内容在您确认之前都不会写入您的记录。

桌面端默认开启。Android 与 iOS 默认为"不使用蜂窝数据"，因此手机只会在 Wi-Fi 或有线连接下进行这项工作。请注意，应用只能识别连接的类型，无法判断它是否计费——例如手机热点同样会被识别为 Wi-Fi。您可以随时在"设置 → 数据 → 后台更新资料库信息"中更改此项，包括完全关闭。另有一个独立开关控制是否提前下载封面图，该开关默认关闭。

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

数据备份

应用提供本地备份功能。备份文件存储在您的设备上，包含您的所有番剧数据和封面图片。备份文件的存储和管理完全由您掌控。

政策变更

本隐私政策可能会不时更新。更新版本将在应用内或相关分发渠道发布。''';

  static const _zhTW = '''隱私政策

感謝您使用 MyAnime!!!!!。我們非常重視您的隱私。本隱私政策說明了應用程式如何處理您的資料。

資料收集

MyAnime!!!!! 不收集、上傳或分享任何個人資訊。應用程式不包含任何分析工具、廣告追蹤器或資料收集功能。

資料儲存

您在應用程式中輸入的所有資料——番劇資訊、觀看紀錄、封面圖片和設定——均儲存在您的裝置本機。您可以隨時更改儲存路徑（僅桌面版）。

網路存取

MyAnime!!!!! 僅在以下情況下存取網際網路：

• 搜尋番劇資訊（完整版專有）：當您主動搜尋番劇時，應用程式會向 bangumi.tv、MyAnimeList（Jikan API）、acgsecrets.hk、anime1.me 和 filmarks.com 傳送請求，以取得公開的番劇資訊，如標題、簡介、封面和集數。透過 App Store 或 Google Play 分發的版本不包含此功能。

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

資料備份

應用程式提供本機備份功能。備份檔案儲存在您的裝置上，包含您的所有番劇資料和封面圖片。備份檔案的儲存和管理完全由您掌控。

政策變更

本隱私政策可能會不時更新。更新版本將在應用程式內或相關分發管道發布。''';

  static const _ja = '''プライバシーポリシー

MyAnime!!!!! をご利用いただきありがとうございます。私たちはお客様のプライバシーを重視しています。このプライバシーポリシーは、アプリがお客様のデータをどのように取り扱うかを説明します。

データ収集

MyAnime!!!!! は個人情報の収集、アップロード、共有を一切行いません。アプリにはアナリティクス、広告トラッカー、データ収集機能は含まれていません。

データ保存

アプリに入力されたすべてのデータ（アニメ情報、視聴履歴、カバー画像、設定）は、お客様のデバイスにローカルで保存されます。保存先はいつでも変更できます（デスクトップ版のみ）。

ネットワークアクセス

MyAnime!!!!! は以下の場合にのみインターネットにアクセスします：

• アニメ情報の検索と更新（完全版のみ）：お客様がアニメを検索した際、または保存済みアニメのデータベース情報を更新した際、アプリは bangumi.tv、MyAnimeList（Jikan API）、AniList（anilist.co）、acgsecrets.hk、anime1.me、filmarks.com にリクエストを送信し、タイトルおよび別名、あらすじ、カバー画像、話数、放送スケジュール、制作会社、ジャンル、各サイトの公開評価などの公開情報を取得します。送信されるのは検索文字列または保存済みのソースページのアドレスのみで、お客様の視聴データは一切含まれません。App Store または Google Play で配信されるバージョンにはこの機能は含まれていません。

• バックグラウンドでのデータベース情報の更新（完全版のみ、1.5.0 以降）：アプリの起動中、上記のリクエストを、お客様が何も操作しなくても自動的に実行することがあります。すでに追加済みのアニメについては保存されたデータベース情報を更新し、情報が不足しているアニメについては検索を行います。送信先のサイト、リクエストの内容、制限はいずれも同じです。送信されるのはタイトルまたは保存済みのソースページのアドレスのみで、お客様の視聴データは一切含まれません。この方法で見つかった情報のうち、お客様ご自身の項目を変更するものは「提案」されるだけであり、お客様が確認するまで記録に書き込まれることはありません。

• 手動での更新確認（完全版のみ、1.5.1 以降）：「利用できる更新」画面には「更新を確認」ボタンがあり、確認が必要なアニメすべてに対して上記と同じリクエストを直ちに実行します。お客様が明示的に指示した操作であるため、このボタンはバックグラウンド更新をオフにしていても動作し、Wi-Fi/モバイル通信の設定も参照しません。バックグラウンド更新がオフのとき、これが唯一の確認手段だからです。ネットワークに接続されていない場合は実行を拒否します。実行中は進捗が表示され、いつでも停止できます。見つかった内容は、お客様が確認するまで記録に書き込まれることはありません。

デスクトップでは既定でオンです。Android と iOS では既定で「モバイルデータを使わない」に設定されており、スマートフォンは Wi-Fi または有線接続の場合にのみこの処理を行います。なお、アプリが判別できるのは接続の種類のみで、従量制かどうかは分かりません。たとえばスマートフォンのテザリングも Wi-Fi として認識されます。この設定は「設定 → データ → バックグラウンドでデータベース情報を更新」からいつでも変更でき、完全にオフにすることもできます。カバー画像を事前にダウンロードするかどうかは別のスイッチで制御され、既定ではオフです。

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

データバックアップ

アプリはローカルバックアップ機能を提供しています。バックアップファイルはお客様のデバイスに保存され、すべてのアニメデータとカバー画像が含まれます。バックアップファイルの保存と管理は完全にお客様の管理下にあります。

ポリシーの変更

このプライバシーポリシーは随時更新される場合があります。更新版はアプリ内または関連する配信チャネルで公開されます。''';
}
