// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'MyAnime!!!!!';

  @override
  String get navHome => 'ホーム';

  @override
  String get navManage => '管理';

  @override
  String get navStats => '統計';

  @override
  String get navSettings => '設定';

  @override
  String homeAiringOn(String date) {
    return '$date 放送';
  }

  @override
  String homeUnwatched(int count) {
    return '未視聴 ($count)';
  }

  @override
  String get homeEmpty => 'アニメがありません。追加して始めましょう！';

  @override
  String get animeTitle => 'タイトル';

  @override
  String get animeTitleJa => '日本語タイトル';

  @override
  String get animeSeason => 'クール';

  @override
  String get animeStartEp => '開始話';

  @override
  String get animeEndEp => '最終話';

  @override
  String get animeType => 'タイプ';

  @override
  String get animeTypeAuto => '自動';

  @override
  String get animeTypeSingleCour => '1クール';

  @override
  String get animeTypeHalfYear => '2クール';

  @override
  String get animeTypeFullYear => '4クール';

  @override
  String get animeTypeLongRunning => '長期放送';

  @override
  String get animeTypeAllAtOnce => '一挙放送';

  @override
  String get animeAirDay => '放送曜日';

  @override
  String get animeAirTime => '放送時間';

  @override
  String get animeAirTimeHelper => '日本時間、25:00形式対応';

  @override
  String get animeFirstAirDate => '初回放送日';

  @override
  String get animeNotes => 'メモ';

  @override
  String get animeWatchUrl => '視聴URL';

  @override
  String get animeInfoUrl => '情報URL';

  @override
  String get animeOpenUrl => '視聴';

  @override
  String get animeOpenInfoUrl => '情報';

  @override
  String get searchAnimeInfo => '作品情報を検索';

  @override
  String get searchHint => 'タイトルを入力して検索…';

  @override
  String get searchButton => '検索';

  @override
  String get searchNoResults => '結果が見つかりません';

  @override
  String get searchCoverImage => 'カバー画像';

  @override
  String get searchFetchCover => '取得';

  @override
  String get searchCurrent => '現在';

  @override
  String get searchFetched => '取得済';

  @override
  String get searchApply => '適用';

  @override
  String get searchWatchUrl => 'anime1.meで視聴URLを検索';

  @override
  String get searchWatchUrlSet => '視聴URLを入力しました';

  @override
  String get searchWatchUrlTitle => '視聴URL検索';

  @override
  String get searchWatchUrlEmpty => '一致する視聴URLが見つかりません';

  @override
  String get animeEpisodes => '話';

  @override
  String get animeEpisodeList => 'エピソード一覧';

  @override
  String animeEpisodeShort(int ep) {
    return '第$ep話';
  }

  @override
  String get animeAdd => 'アニメを追加';

  @override
  String get animeEdit => 'アニメを編集';

  @override
  String get animeSearchHint => 'アニメを検索…';

  @override
  String get animeNoResults => '今期のアニメはありません';

  @override
  String get animeFieldRequired => '必須';

  @override
  String animeMissingFields(String fields) {
    return '次の項目を入力してください：$fields';
  }

  @override
  String get animeWatched => '視聴済み';

  @override
  String get animeUnwatched => '未視聴';

  @override
  String get animeSkipped => 'スキップ';

  @override
  String get animeShiftForward => '1週前に移動（この話以降）';

  @override
  String get animeShiftBackward => '1週後に移動（この話以降）';

  @override
  String get animeMarkAllWatched => '全て視聴済み';

  @override
  String get animeMarkAllUnwatched => '全て未読';

  @override
  String get animeResetSchedule => 'スケジュールリセット';

  @override
  String get animeResetScheduleConfirm =>
      'すべてのエピソードの日程調整を初回放送日に基づくオリジナルスケジュールにリセットしますか？';

  @override
  String get animeAbandon => '視聴中止';

  @override
  String get animeResume => '視聴再開';

  @override
  String get animePrevSeason => '前シーズン';

  @override
  String get animeNextSeason => '次シーズン';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get commonDelete => '削除確認';

  @override
  String commonDeleteConfirm(String item) {
    return '「$item」を削除しますか？';
  }

  @override
  String get commonDontAskMinutes => '5分間確認しない';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsThemeSystem => 'システム';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSystem => 'システム';

  @override
  String get settingsReminder => '毎日リマインダー';

  @override
  String get settingsReminderOff => 'オフ';

  @override
  String get settingsReminderTime => 'リマインダー時刻';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsAbout => 'バージョン情報';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get settingsLicense => 'ライセンス (GPLv3)';

  @override
  String get settingsLicenses => 'オープンソースライセンス';

  @override
  String get settingsConfirm => '確認';

  @override
  String get settingsWebDAVSync => 'WebDAV同期';

  @override
  String get settingsWebDAVServerURL => 'サーバーURL';

  @override
  String get settingsWebDAVUsername => 'ユーザー名';

  @override
  String get settingsWebDAVPassword => 'パスワード';

  @override
  String get settingsWebDAVRemotePath => 'リモートパス';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTest => 'テスト';

  @override
  String get settingsWebDAVAutoSync => '自動同期';

  @override
  String get settingsWebDAVSyncNow => '今すぐ同期';

  @override
  String get settingsWebDAVDisconnect => '切断';

  @override
  String get settingsWebDAVConfigSaved => '設定を保存しました';

  @override
  String get settingsWebDAVConfigRemoved => '設定を削除しました';

  @override
  String get settingsWebDAVConnectionSuccess => '接続成功';

  @override
  String get settingsWebDAVConnectionFailed => '接続失敗';

  @override
  String get settingsWebDAVSyncSuccess => '同期完了';

  @override
  String get settingsWebDAVSyncFailed => '同期失敗';

  @override
  String get backupTitle => 'バックアップ';

  @override
  String get backupSubtitle => '完全ローカルバックアップ（データ＋画像）';

  @override
  String get backupCreate => 'バックアップ作成';

  @override
  String get backupCreated => 'バックアップを作成しました';

  @override
  String get backupAutoBackup => '自動バックアップ';

  @override
  String get backupRetention => '保持期間';

  @override
  String get backupKeepForever => '永久保持';

  @override
  String backupKeepDays(int days) {
    return '$days日間';
  }

  @override
  String backupHistory(int count) {
    return '履歴 ($count)';
  }

  @override
  String get backupNoBackups => 'バックアップはありません';

  @override
  String get backupRestore => '復元';

  @override
  String get backupRestoreConfirm => '現在のデータが上書きされます。続行しますか？';

  @override
  String get backupRestored => 'バックアップを復元しました';

  @override
  String get backupRestoreFailed => '復元に失敗しました';

  @override
  String get backupDeleteConfirm => 'このバックアップを削除しますか？';

  @override
  String get backupRestoreModules => '復元するデータを選択';

  @override
  String get backupSelectAll => 'すべて選択';

  @override
  String get exportData => 'データをエクスポート';

  @override
  String get importData => 'データをインポート';

  @override
  String get exportSuccess => 'データのエクスポートに成功しました';

  @override
  String get importSuccess => 'データのインポートに成功しました';

  @override
  String get importFailed => 'インポートに失敗しました';

  @override
  String get importConfirm => '現在のデータが上書きされます。続行しますか？';

  @override
  String get settingsStorageLocation => '保存場所';

  @override
  String get settingsStoragePathHint =>
      'カスタムデータ保存ディレクトリパスを入力してください。空欄でデフォルトを使用します。';

  @override
  String get settingsDirectoryPath => 'ディレクトリパス';

  @override
  String get settingsResetDefault => 'デフォルトに戻す';

  @override
  String get settingsResetDefaultLocation => '保存場所をデフォルトにリセットしました';

  @override
  String get settingsStoragePathUpdated => '保存場所を更新しました';

  @override
  String get dataMigration => 'データフォルダを開く';

  @override
  String get dataMigrationDesc => 'アプリケーションデータディレクトリを開く';

  @override
  String get homeCalendarJst => 'カレンダーの日付は JST（UTC+9）';

  @override
  String get animeShare => '共有';

  @override
  String get shareCopied => '画像をクリップボードにコピーしました';

  @override
  String get shareCopy => 'コピー';

  @override
  String get shareSaveAs => '名前を付けて保存';

  @override
  String get shareSaved => '画像を保存しました';

  @override
  String get shareFailed => '共有に失敗しました';

  @override
  String get shareUrlOptions => 'URLを含める';

  @override
  String get statsTitle => '統計';

  @override
  String get statsQuarter => 'クール';

  @override
  String get statsYear => '年間';

  @override
  String get statsAll => 'すべて';

  @override
  String get statsTracked => '視聴中';

  @override
  String get statsCompleted => '完了';

  @override
  String get statsDropped => '中止';

  @override
  String get statsWatching => '追跡中';

  @override
  String get statsNotStarted => '未開始';

  @override
  String get statsTrend => 'トレンド';

  @override
  String get manageJumpToQuarter => 'クールに移動';

  @override
  String get manageNoSearchResults => '該当するアニメが見つかりません';

  @override
  String get manageOther => 'その他';

  @override
  String get dayMon => '月';

  @override
  String get dayTue => '火';

  @override
  String get dayWed => '水';

  @override
  String get dayThu => '木';

  @override
  String get dayFri => '金';

  @override
  String get daySat => '土';

  @override
  String get daySun => '日';

  @override
  String get seasonWinter => '冬';

  @override
  String get seasonSpring => '春';

  @override
  String get seasonSummer => '夏';

  @override
  String get seasonFall => '秋';

  @override
  String get reminderNotifBody => 'アニメのスケジュールを確認してください！';

  @override
  String reminderAiringToday(int count) {
    return '今日放送: $count話';
  }

  @override
  String reminderUnwatched(int count) {
    return '未視聴: $count話';
  }

  @override
  String syncConflictTitle(String name) {
    return '同期競合: $name';
  }

  @override
  String get syncConflictDesc => 'このアニメは最後の同期以降、両方のデバイスで変更されました。';

  @override
  String get syncLocalVersion => 'ローカル版:';

  @override
  String get syncRemoteVersion => 'リモート版:';

  @override
  String syncModifiedAt(String time) {
    return '更新日時: $time';
  }

  @override
  String syncEpisodeRange(int start, int end) {
    return 'エピソード: $start〜$end';
  }

  @override
  String syncWatched(int count) {
    return '視聴済み: $count';
  }

  @override
  String get syncKeepLocal => 'ローカルを保持';

  @override
  String get syncKeepRemote => 'リモートを保持';

  @override
  String searchEpisodesCount(int count) {
    return '$count話';
  }

  @override
  String get animeSeasonHint => '第1期';

  @override
  String get shareTypeTitle => '共有方法';

  @override
  String get shareAsImage => '画像で共有';

  @override
  String get shareAsData => 'データファイルで共有';

  @override
  String get importAnimeSuccess => 'アニメをインポートしました';

  @override
  String get importAnimeFailed => 'インポートに失敗しました';

  @override
  String get addAnimeCreate => '新規作成';

  @override
  String get addAnimeImport => 'ファイルからインポート';
}
