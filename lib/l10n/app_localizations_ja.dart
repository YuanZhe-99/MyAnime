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
  String get navKana => 'かな';

  @override
  String get navSettings => '設定';

  @override
  String homeAiringOn(String date) {
    return '$date 放送';
  }

  @override
  String homeUnwatched(int animeCount, int episodeCount) {
    return '未視聴: $animeCount作品、$episodeCount話';
  }

  @override
  String get homeEmpty => 'アニメがありません。追加して始めましょう！';

  @override
  String get homeCalendarTimeNoteJst => 'カレンダーの日付は日本時間（UTC+9）を使用';

  @override
  String get homeCalendarTimeNoteLocal => 'カレンダーの日付は端末の現地時間を使用（放送時刻は日本時間のまま計算）';

  @override
  String get calendarFormatMonth => '月';

  @override
  String get calendarFormatTwoWeeks => '2週間';

  @override
  String get calendarFormatWeek => '週';

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
  String get animeRating => '評価';

  @override
  String get animeRatingOverall => '総合';

  @override
  String get animeRatingVisual => '映像/演出';

  @override
  String get animeRatingStory => 'ストーリー';

  @override
  String get animeRatingCharacter => 'キャラクター';

  @override
  String get animeRatingMusic => '音楽/音響';

  @override
  String get animeRatingEnjoyment => '満足度/おすすめ度';

  @override
  String get animeRatingAutoHint => '任意、0-10点。総合評価は項目平均でも計算できます。';

  @override
  String get animeRatingOverallHelper => '空欄の場合は項目平均を使用';

  @override
  String get animeRatingInvalid => '0から10までの評価を入力してください';

  @override
  String get animeRatingManualOverall => '手動の総合評価';

  @override
  String get animeRatingAutoOverall => '項目平均による総合評価';

  @override
  String get searchAnimeInfo => '作品情報を検索';

  @override
  String get searchHint => 'タイトルを入力して検索…';

  @override
  String get searchButton => '検索';

  @override
  String get searchNoResults => '結果が見つかりません';

  @override
  String searchCoverFetchFailed(String error) {
    return 'カバー画像の取得に失敗しました: $error';
  }

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
  String get settingsHomeCalendarLayout => 'ホームカレンダー表示';

  @override
  String get settingsHomeCalendarLayoutLocal => 'ローカル';

  @override
  String get settingsHomeCalendarLayoutJapanese => '日本（日月火水木金土）';

  @override
  String get settingsWeekStartDay => '週の開始曜日';

  @override
  String get settingsWeekStartLockedJapanese => '日本カレンダーは日曜始まりに固定されます';

  @override
  String get settingsHomeCalendarTimeBasis => 'ホームカレンダー時間';

  @override
  String get settingsHomeCalendarTimeBasisJst => '日本時間';

  @override
  String get settingsHomeCalendarTimeBasisLocal => '現地時間';

  @override
  String get settingsHomeCalendarTimeBasisDesc => 'アニメの放送時刻は日本時間のまま計算されます。';

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
  String get settingsWebDAVNextcloud => 'Nextcloud プリセット';

  @override
  String get settingsWebDAVTestConnection => '接続テスト';

  @override
  String get settingsWebDAVAutoSync => '自動同期';

  @override
  String get settingsWebDAVAutoSyncDesc => '編集後やアプリ再開時に自動的に同期します';

  @override
  String get settingsWebDAVSyncNow => '今すぐ同期';

  @override
  String get settingsWebDAVSyncing => '同期中…';

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
  String get settingsWebDAVAutoSyncFailed => '自動同期失敗';

  @override
  String get settingsWebDAVAutoSyncConflict => '自動同期で競合を検出';

  @override
  String get settingsWebDAVLastSuccess => '前回の同期成功';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同期完了（画像$count件の転送に失敗）';
  }

  @override
  String get settingsWebDAVForceUpload => '強制アップロード';

  @override
  String get settingsWebDAVForceDownload => '強制ダウンロード';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => '強制アップロードしますか？';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      'リモートのデータと画像をローカルの内容で上書きします。前回の同期以降のリモートの変更は失われます。';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => '強制ダウンロードしますか？';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      'ローカルのデータと画像をリモートの内容で置き換えます。前回の同期以降のローカルの変更は失われます。';

  @override
  String get syncPhaseConnecting => '接続中…';

  @override
  String syncPhaseDownloadingData(String file, int current, int total) {
    return '$file をダウンロード中（$current/$total）';
  }

  @override
  String syncPhaseMerging(String file) {
    return '$file をマージ中…';
  }

  @override
  String syncPhaseUploadingData(String file) {
    return '$file をアップロード中…';
  }

  @override
  String syncPhaseUploadingImages(int current, int total) {
    return '画像をアップロード中（$current/$total）';
  }

  @override
  String syncPhaseDownloadingImages(int current, int total) {
    return '画像をダウンロード中（$current/$total）';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get backupTitle => 'バックアップ';

  @override
  String get backupSubtitle => '完全ローカルバックアップ（データ＋画像）';

  @override
  String get backupCreate => 'バックアップを作成';

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
  String get backupRestoreModules => '復元するモジュールを選択';

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
  String get shareSaveAll => 'すべて保存';

  @override
  String sharePagesLabel(int count) {
    return '$count ページ';
  }

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
  String get statsTracked => '追跡中';

  @override
  String get statsCompleted => '完了';

  @override
  String get statsDropped => '中止';

  @override
  String get statsWatching => '視聴中';

  @override
  String get statsNotStarted => '未開始';

  @override
  String get statsTrend => 'トレンド';

  @override
  String get statsRanking => 'ランキング';

  @override
  String get statsRankingFilters => 'フィルター';

  @override
  String get statsRankingTimeFilter => '期間';

  @override
  String get statsRankingTypeFilter => 'タイプ';

  @override
  String get statsRankingAllTypes => 'すべてのタイプ';

  @override
  String get statsRankingSortBy => '並び替え';

  @override
  String get statsRankingDescending => '高い順';

  @override
  String get statsRankingAscending => '低い順';

  @override
  String get statsRankingDescShort => '降順';

  @override
  String get statsRankingAscShort => '昇順';

  @override
  String get statsRankingCustomRange => 'カスタム期間';

  @override
  String get statsRankingSelectYear => '年を選択';

  @override
  String get statsRankingStartQuarter => '開始クール';

  @override
  String get statsRankingEndQuarter => '終了クール';

  @override
  String get statsRankingEmpty => '条件に一致する評価済みアニメはありません';

  @override
  String statsRankingCount(int count) {
    return '評価済みアニメ $count 件';
  }

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
  String reminderAiringToday(int animeCount, int episodeCount) {
    return '今日放送: $animeCount作品、$episodeCount話';
  }

  @override
  String reminderUnwatched(int animeCount, int episodeCount) {
    return '未視聴: $animeCount作品、$episodeCount話';
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
  String get shareAsTxt => 'TXTで共有（名前のみ）';

  @override
  String get statsShareTxtEmpty => '書き出すアニメがありません';

  @override
  String get importAnimeSuccess => 'アニメをインポートしました';

  @override
  String get importAnimeFailed => 'インポートに失敗しました';

  @override
  String get statsShare => '統計を共有';

  @override
  String statsShareSummary(String scope, int count) {
    return '$scope · $count 件';
  }

  @override
  String get importBundleTitle => 'アニメをインポート';

  @override
  String importBundleCount(int count) {
    return 'ファイル内に $count 件のアニメが見つかりました';
  }

  @override
  String importBundleConflictTitle(String name) {
    return 'インポートの競合: $name';
  }

  @override
  String get importBundleConflictDesc => 'このアニメは既にライブラリに存在します。';

  @override
  String get importBundleLocalVersion => 'ローカル版:';

  @override
  String get importBundleImportedVersion => 'インポート版:';

  @override
  String get importBundleKeepLocal => 'ローカルを保持';

  @override
  String get importBundleKeepImport => 'インポート版を使用';

  @override
  String get importBundleMerge => '統合';

  @override
  String importBundleSuccess(int count) {
    return '$count 件のアニメをインポートしました';
  }

  @override
  String get importBundleNoConflicts => '競合なし、すべてインポート中…';

  @override
  String get settingsDuplicateCheck => '重複チェック';

  @override
  String get settingsDuplicateCheckDesc => '重複するアニメ記録を検索して統合';

  @override
  String get duplicateCheckTitle => '重複チェック';

  @override
  String get duplicateCheckEmpty => '重複は見つかりませんでした';

  @override
  String duplicateCheckFound(int count) {
    return '$count グループの重複が見つかりました';
  }

  @override
  String get duplicateReasonSameId => '同じ ID';

  @override
  String get duplicateReasonSameUrl => '同じ URL';

  @override
  String get duplicateReasonSameTitleSeason => '同じタイトル/クール';

  @override
  String duplicateGroupLabel(int index, int total, String reason) {
    return 'グループ $index/$total: $reason';
  }

  @override
  String get duplicateKeepFirst => 'これを保持';

  @override
  String get duplicateMergeAll => 'すべてこれに統合';

  @override
  String get duplicateDeleteOthers => '他を削除';

  @override
  String get duplicateResolved => '重複を解決しました';

  @override
  String get duplicateResolveConfirm => 'この重複グループを解決しますか？';

  @override
  String get addAnimeCreate => '新規作成';

  @override
  String get addAnimeImport => 'ファイルからインポート';

  @override
  String get exportAsZip => 'ZIPでエクスポート';

  @override
  String get exportAsZipDesc => '完全データアーカイブ（アニメデータ＋カバー画像）、バックアップや移行用';

  @override
  String get exportAsMarkdown => 'Markdownでエクスポート';

  @override
  String get exportAsMarkdownDesc => '放送日順のアニメリストと視聴状況、LLMパーソナライズ用';

  @override
  String get trayShow => '表示';

  @override
  String get trayQuit => '終了';

  @override
  String get settingsMinimizeToTray => 'トレイに最小化';

  @override
  String get settingsCloseToTray => 'トレイに閉じる';

  @override
  String get settingsAutoStart => 'スタートアップ時に起動';

  @override
  String get settingsApiServer => 'APIサーバー設定';

  @override
  String get settingsApiEnabled => 'ローカルAPIサーバー';

  @override
  String get settingsApiListenAddress => 'リッスンアドレス';

  @override
  String get settingsApiPort => 'ポート';

  @override
  String get settingsApiUsername => 'ユーザー名';

  @override
  String get settingsApiPassword => 'パスワード';

  @override
  String settingsApiRunning(int port) {
    return 'ポート$portで稼働中';
  }

  @override
  String get settingsApiStopped => '停止中';

  @override
  String get settingsApiNeedCredentials =>
      'localhost以外でリッスンする場合、ユーザー名とパスワードを設定してください';

  @override
  String get settingsApiRestart => 'サーバー再起動';

  @override
  String settingsApiRestarted(int port) {
    return 'APIサーバーをポート$portで再起動しました';
  }

  @override
  String get kanaTitle => 'かな早見表';

  @override
  String get kanaScriptHiragana => 'ひらがな';

  @override
  String get kanaScriptKatakana => 'カタカナ';

  @override
  String get kanaSearchHint => 'かな・ローマ字を検索…';

  @override
  String kanaSearchResults(int count) {
    return '一致 ($count)';
  }

  @override
  String get kanaNoMatches => '一致するかながありません';

  @override
  String get kanaBasicSection => '五十音';

  @override
  String get kanaVoicedSection => '濁音・半濁音';

  @override
  String get kanaYoonSection => '拗音';

  @override
  String get kanaRulesSection => '発音ルール';

  @override
  String get kanaRuleMoraTitle => '一かな一拍';

  @override
  String get kanaRuleMoraBody => '各かなは一つのモーラです。か・き・く・け・このように一定のリズムで発音します。';

  @override
  String get kanaRuleVowelsTitle => '母音は安定';

  @override
  String get kanaRuleVowelsBody =>
      'a, i, u, e, o は短くはっきり保ちます。英語の弱い母音のように曖昧にしません。';

  @override
  String get kanaRuleDakutenTitle => '濁点と半濁点';

  @override
  String get kanaRuleDakutenBody =>
      '゛は子音を濁らせます: k は g、s は z、t は d、h は b。゜は h を p にします。';

  @override
  String get kanaRuleYoonTitle => '拗音';

  @override
  String get kanaRuleYoonBody => '小さい ゃ/ゅ/ょ はイ段のかなと結びます: き + ゃ = きゃ kya。';

  @override
  String get kanaRuleSokuonTitle => '小さいつ';

  @override
  String get kanaRuleSokuonBody => '小さい っ/ッ は次の子音を短く詰めます。例: まって matte。';

  @override
  String get kanaRuleLongVowelsTitle => '長音';

  @override
  String get kanaRuleLongVowelsBody =>
      'ー はカタカナの音を伸ばします。ひらがなでは おう が長い o、えい が長い e になることが多いです。';

  @override
  String get kanaRuleNTitle => 'ん / ン';

  @override
  String get kanaRuleNBody => '基本は n。m, b, p の前では m に近く、k, g の前では柔らかい鼻音になります。';

  @override
  String get statsShareStatusTitle => '含める視聴ステータス';

  @override
  String get statsShareStatusHint => '含める視聴ステータスを選択してください';

  @override
  String get statsShareLimitTitle => '大量画像シェア';

  @override
  String statsShareLimitWarning(int count) {
    return '$count 件あります。生成に時間がかかる場合があります。';
  }

  @override
  String get statsShareLimitEnable => '件数上限を設定';

  @override
  String get statsShareLimitCount => '上限';

  @override
  String get statsShareLimitPriority => '優先順位';

  @override
  String get statsSharePriorityRecent => '新しい順（初放送日）';

  @override
  String get statsSharePriorityOldest => '古い順（初放送日）';

  @override
  String get statsShareGenerating => '画像を生成中です。時間がかかる場合があります…';

  @override
  String statsShareGeneratingProgress(int done, int total) {
    return 'カバー読み込み: $done/$total';
  }

  @override
  String statsShareTruncated(int shown, int total) {
    return '$shown/$total 件（切り詰め）';
  }

  @override
  String get settingsDesktop => 'デスクトップ';
}
