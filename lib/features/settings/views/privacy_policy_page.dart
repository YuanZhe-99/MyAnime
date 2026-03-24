import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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

• Searching for anime information: When you actively search for anime, the app sends requests to bangumi.tv, MyAnimeList (Jikan API), acgsecrets.hk, anime1.me and filmarks.com to retrieve publicly available anime information such as titles, summaries, cover art, and episode counts.

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

• 搜索番剧信息：当您主动搜索番剧时，应用会向 bangumi.tv、MyAnimeList（Jikan API）、acgsecrets.hk、anime1.me 和 filmarks.com 发送请求，以获取公开的番剧信息，如标题、简介、封面和集数。

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

• 搜尋番劇資訊：當您主動搜尋番劇時，應用程式會向 bangumi.tv、MyAnimeList（Jikan API）、acgsecrets.hk、anime1.me 和 filmarks.com 傳送請求，以取得公開的番劇資訊，如標題、簡介、封面和集數。

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

• アニメ情報の検索：お客様がアニメを検索した際、アプリは bangumi.tv、MyAnimeList（Jikan API）、acgsecrets.hk、anime1.me、filmarks.com にリクエストを送信し、タイトル、あらすじ、カバー画像、話数などの公開情報を取得します。

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

データバックアップ

アプリはローカルバックアップ機能を提供しています。バックアップファイルはお客様のデバイスに保存され、すべてのアニメデータとカバー画像が含まれます。バックアップファイルの保存と管理は完全にお客様の管理下にあります。

ポリシーの変更

このプライバシーポリシーは随時更新される場合があります。更新版はアプリ内または関連する配信チャネルで公開されます。''';
}
