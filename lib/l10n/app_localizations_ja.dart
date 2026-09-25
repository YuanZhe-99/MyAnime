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
  String get animeLocalArchive => 'ローカル保存';

  @override
  String get animeLocalArchiveHint => '任意。ダウンロードした動画を保管しているかどうか。';

  @override
  String get animeLocalArchiveArchived => 'ローカルに保存済み';

  @override
  String get animeLocalArchiveNone => '未保存';

  @override
  String get animeArchiveSource => 'ソース';

  @override
  String get animeArchiveResolution => '解像度';

  @override
  String get animeArchiveOther => 'その他';

  @override
  String get animeArchiveCopies => '保存本数';

  @override
  String get animeArchiveCopiesInvalid => '正の整数を入力してください';

  @override
  String animeArchiveCopiesValue(int count) {
    return '×$count';
  }

  @override
  String get animeArchiveLocation => '保管場所・リポジトリコード';

  @override
  String get animeArchiveLocationHint => '例: NAS-01、HDD-C3';

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
  String get searchWatchUrlAliasHint => 'bangumi.tv の別名で照合';

  @override
  String anime1Ongoing(int episode) {
    return '第$episode話まで更新';
  }

  @override
  String anime1EpisodeRange(String range) {
    return '第$range話';
  }

  @override
  String get anime1Movie => '劇場版';

  @override
  String get anime1Special => '特別編';

  @override
  String anime1Short(int episode) {
    return '$episode話まで';
  }

  @override
  String get anime1CheckProgress => 'anime1 を確認';

  @override
  String anime1ProgressLabel(String status) {
    return 'anime1: $status';
  }

  @override
  String get anime1ProgressUnknown => 'anime1: 話数情報が見つかりません';

  @override
  String anime1ProgressFailed(String error) {
    return 'anime1 の確認に失敗しました: $error';
  }

  @override
  String get searchSort => '並び替え';

  @override
  String get searchSortRelevance => '関連度';

  @override
  String get searchSortAirDate => '放送開始日';

  @override
  String get searchSortEpisodes => '話数';

  @override
  String get searchSortSource => 'ソース';

  @override
  String get searchFilter => '絞り込み';

  @override
  String get searchFilterSources => 'ソース';

  @override
  String get searchFilterWithCover => 'カバー画像がある結果のみ';

  @override
  String get searchFilterWithAirDate => '放送日がある結果のみ';

  @override
  String get searchFilterReset => '絞り込みをリセット';

  @override
  String get searchGroupBySource => 'ソースごとにグループ化';

  @override
  String searchResultCount(int shown, int total) {
    return '全 $total 件中 $shown 件を表示';
  }

  @override
  String get searchNoMatchingResults => '現在の絞り込み条件に一致する結果はありません';

  @override
  String get searchDetailsTitle => '結果の詳細';

  @override
  String get searchAllTitles => 'すべてのタイトル';

  @override
  String get searchDetailsHint => '結果を長押しすると全タイトルと詳細を表示します';

  @override
  String get searchExternalMeta => 'データベース情報';

  @override
  String searchExternalMetaValue(int count, String source) {
    return '$source からの $count 項目';
  }

  @override
  String searchProgressRound1(int done, int total) {
    return '検索中 $done / $total ソース…';
  }

  @override
  String searchProgressRound2(int done, int total) {
    return '再検索 $done / $total ソース…';
  }

  @override
  String get searchSourceFailed => '失敗';

  @override
  String searchSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
      zero: '結果なし',
    );
    return '$_temp0';
  }

  @override
  String get animeStudios => '制作会社';

  @override
  String get animeGenres => 'ジャンル';

  @override
  String get animeFormat => '作品形式';

  @override
  String get animeStatus => '放送状況';

  @override
  String get animeDuration => '1話あたりの長さ';

  @override
  String animeDurationValue(int minutes) {
    return '$minutes 分/話';
  }

  @override
  String get animeEndDate => '放送終了日';

  @override
  String get animeAlternateTitles => '別名';

  @override
  String get animeExternalMeta => 'データベース情報';

  @override
  String get animeExternalRatings => '外部評価';

  @override
  String animeExternalVotes(int votes) {
    return '$votes 件の評価';
  }

  @override
  String animeExternalRank(int rank) {
    return 'ランキング #$rank';
  }

  @override
  String get animeRefreshMeta => 'データベース情報を更新';

  @override
  String get animeRefreshMetaDone => 'データベース情報を更新しました';

  @override
  String animeRefreshMetaFailed(String error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get animeRefreshMetaNone => '更新できるソースページが保存されていません';

  @override
  String animeRefreshedAt(String date) {
    return '$date に更新';
  }

  @override
  String get metaUpdatesTitle => '利用可能な更新';

  @override
  String get metaUpdatesTooltip => '利用可能な更新';

  @override
  String get metaUpdatesEmpty => '利用可能な更新はありません';

  @override
  String get metaUpdatesEmptyHint => '情報が不足している記録はバックグラウンドで自動的に検索されます。';

  @override
  String metaUpdatesCount(int count) {
    return '$count 件';
  }

  @override
  String get metaUpdatesApply => '適用';

  @override
  String get metaUpdatesDismiss => '無視';

  @override
  String get metaUpdatesApplyPage => 'このページを更新';

  @override
  String get metaUpdatesApplyAll => 'すべて更新';

  @override
  String get metaUpdatesConfirmTitle => '更新の確認';

  @override
  String metaUpdatesConfirmPage(int count) {
    return 'このページの $count 件を適用しますか？';
  }

  @override
  String metaUpdatesConfirmAll(int count) {
    return 'すべての $count 件を適用しますか？';
  }

  @override
  String metaUpdatesConfirmAgain(int count) {
    return '$count 件の記録を一度に変更します。適用しますか？';
  }

  @override
  String metaUpdatesApplied(int count) {
    return '$count 件の記録を更新しました';
  }

  @override
  String get metaUpdatesManualPick => '手動選択が必要';

  @override
  String get metaUpdatesManualPickHint => '確実な候補が見つかりませんでした。記録を開いて手動で検索してください。';

  @override
  String metaUpdatesExcludedManual(int count) {
    return '手動選択が必要な $count 件は除外されます';
  }

  @override
  String get metaUpdatesCurrent => '現在';

  @override
  String get metaUpdatesProposed => '変更後';

  @override
  String get metaUpdatesEmptyValue => '（空）';

  @override
  String metaUpdatesFrom(String source) {
    return '$source より';
  }

  @override
  String metaUpdatesMatch(int percent) {
    return '一致度 $percent%';
  }

  @override
  String get metaUpdatesNothingSelected => '項目を1つ以上選択してください';

  @override
  String get metaUpdatesScan => '更新を確認';

  @override
  String get metaUpdatesScanStop => '確認を停止';

  @override
  String metaUpdatesScanProgress(int done, int total) {
    return '$done / $total 件を確認済み';
  }

  @override
  String metaUpdatesScanFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件見つかりました',
      zero: 'まだ見つかっていません',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '確認が完了しました。$count 件の更新が見つかりました',
      zero: '確認が完了しました。利用できる更新はありません',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '確認を停止しました。$count 件の更新が見つかりました',
      zero: '確認を停止しました。利用できる更新はありません',
    );
    return '$_temp0';
  }

  @override
  String get metaUpdatesScanUpToDate => 'すべて最新です';

  @override
  String get metaUpdatesScanOffline => 'ネットワークに接続されていません';

  @override
  String get metaUpdatesManualSearch => '手動で検索';

  @override
  String get settingsMetaAutoUpdate => 'バックグラウンドでデータベース情報を更新';

  @override
  String get settingsMetaAutoUpdateDesc =>
      'アプリの起動中に、保存済みのデータベース情報を更新し、情報が不足している記録を検索します。';

  @override
  String get settingsMetaPolicyOff => 'オフ';

  @override
  String get settingsMetaPolicyNoCellular => 'モバイルデータを使わない';

  @override
  String get settingsMetaPolicyAlways => 'すべての接続';

  @override
  String get settingsMetaPolicyHint =>
      '判別できるのは接続の種類のみで、従量制かどうかは分かりません。スマートフォンのテザリングも Wi-Fi として認識されます。';

  @override
  String get settingsMetaPrefetchCovers => 'カバー画像を事前ダウンロード';

  @override
  String get settingsMetaPrefetchCoversDesc =>
      '既定はオフです。このキャッシュで容量を占めるのはカバー画像のみで、他はすべてテキストです。';

  @override
  String get copyAction => 'コピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

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
  String get seriesTitle => 'シリーズ';

  @override
  String get seriesAuto => '自動でまとめました';

  @override
  String get seriesCurated => '手動で関連付け';

  @override
  String get seriesManage => 'シリーズを管理…';

  @override
  String get seriesLinkTo => 'シリーズに関連付け…';

  @override
  String get seriesAddNext => '次のシーズンを追加';

  @override
  String get seriesRemove => 'シリーズから外す';

  @override
  String get seriesLetAppDecide => 'アプリに任せる';

  @override
  String get seriesSearchHint => 'ライブラリを検索';

  @override
  String get seriesSuggestions => '候補';

  @override
  String get seriesMembers => 'このシリーズ';

  @override
  String get seriesNoMatches => '該当するアニメはありません';

  @override
  String get seriesSaveOrder => '順番を保存';

  @override
  String get syncSeriesLinked => 'シリーズ：手動で関連付け';

  @override
  String get syncSeriesStandalone => 'シリーズ：どのシリーズにも属さない';

  @override
  String get syncSeriesAuto => 'シリーズ：自動';

  @override
  String get recommendationsTitle => '次に観るもの';

  @override
  String get recommendationsEmpty =>
      'おすすめできる作品がまだありません。未視聴のアニメを追加するか、シーズンを観終えると次のシーズンを提案します。';

  @override
  String get recommendationsNotInterested => '興味なし';

  @override
  String get recommendationsNotInLibrary => 'まだライブラリにありません';

  @override
  String reasonNextAfter(String title) {
    return '「$title」の次';
  }

  @override
  String reasonLikeCategories(String categories) {
    return '高く評価した作品と同じ系統：$categories';
  }

  @override
  String reasonSameStudio(String title) {
    return '「$title」と同じスタジオ';
  }

  @override
  String get reasonCatchUp => '未視聴の新しい話があります';

  @override
  String get settingsRecommendations => 'おすすめ';

  @override
  String get settingsRecommendationsDesc =>
      '自分のライブラリから次に観る作品を提案します。「興味なし」はこの端末でのみ非表示になります。';

  @override
  String syncCategories(String list) {
    return '分類：$list';
  }

  @override
  String get syncCategoriesAuto => '分類：自動';

  @override
  String get categoryAction => 'アクション';

  @override
  String get categoryAdventure => '冒険';

  @override
  String get categoryComedy => 'コメディ';

  @override
  String get categoryDrama => 'ドラマ';

  @override
  String get categoryRomance => '恋愛';

  @override
  String get categorySliceOfLife => '日常';

  @override
  String get categoryFantasy => 'ファンタジー';

  @override
  String get categoryIsekai => '異世界';

  @override
  String get categorySciFi => 'SF';

  @override
  String get categoryMecha => 'ロボット';

  @override
  String get categoryMystery => 'ミステリー';

  @override
  String get categorySuspense => 'サスペンス';

  @override
  String get categoryHorror => 'ホラー';

  @override
  String get categoryPsychological => '心理';

  @override
  String get categorySupernatural => '超常';

  @override
  String get categorySports => 'スポーツ';

  @override
  String get categoryMusic => '音楽';

  @override
  String get categorySchool => '学園';

  @override
  String get categoryHistorical => '歴史';

  @override
  String get categoryMilitary => 'ミリタリー';

  @override
  String get categoryGourmet => 'グルメ';

  @override
  String get categoryHealing => '癒し系';

  @override
  String get categoryMagicalGirl => '魔法少女';

  @override
  String get categoriesTitle => '分類';

  @override
  String get categoriesEdit => '分類を編集';

  @override
  String get categoriesReset => '自動に戻す';

  @override
  String get categoriesNone => '分類なし';

  @override
  String get categoriesYours => '自分で選択';

  @override
  String get settingsAutoCategories => '自動分類';

  @override
  String get settingsAutoCategoriesDesc =>
      'データベースが報告するジャンルから、各アニメを分類します。自分で選んだ分類が常に優先されます。';

  @override
  String get aiCategorizeNow => '今すぐ分類';

  @override
  String aiCategorizeProgress(int pending, int total) {
    return '未分類 $pending / $total';
  }

  @override
  String get manageFilterCategory => '分類';

  @override
  String get manageFilterAllCategories => 'すべての分類';

  @override
  String seriesMissingSequel(String title, String source) {
    return '次：$title（$source）';
  }

  @override
  String get seriesMissingSequelHint =>
      'データベースにはありますが、ライブラリにはありません。タップして追加します。';

  @override
  String get seriesSuggestionSpinOff => 'スピンオフ';

  @override
  String get seriesSuggestionAlternative => '別バージョン';

  @override
  String get aiSectionTitle => '分類とおすすめ';

  @override
  String get aiUseOnDevice => 'オンデバイスAIを使う';

  @override
  String get aiUseOnDeviceDesc =>
      '初期状態ではオフです。データベースに分類がない作品の分類を補い、おすすめの短い理由を、この端末に内蔵されたモデルで書きます。何も端末の外に送信されません。';

  @override
  String get aiNeedsFeature => '先に自動分類かおすすめをオンにしてください。';

  @override
  String get aiStatusAvailable => '利用可能';

  @override
  String get aiStatusUnavailable => 'この端末では利用できません';

  @override
  String get aiStatusUnreachable => 'オンデバイスモデルに接続できませんでした';

  @override
  String get aiStatusUnknown => 'このバージョンでは認識できない状態が端末から返されました';

  @override
  String get aiStatusDownloadable => '初回のみダウンロードが必要';

  @override
  String get aiStatusDownloading => 'モデルを準備中…';

  @override
  String get aiStatusNotEnabled => 'Apple Intelligence がオフになっています';

  @override
  String get aiStatusUnsupportedApple =>
      'Apple Intelligence に対応した iOS 26 または macOS 26 が必要です';

  @override
  String get aiTurnOnAppleIntelligence =>
      '設定アプリで Apple Intelligence をオンにしてから、再確認してください。';

  @override
  String get aiCheckAgain => '再確認';

  @override
  String get aiDownload => 'ダウンロード';

  @override
  String aiDownloadedBytes(String megabytes) {
    return '$megabytes MB ダウンロード済み';
  }

  @override
  String get aiDownloadNote =>
      'モデルをダウンロードするのはこのアプリではなくAndroidで、「ダウンロード」をタップしたときだけです。';

  @override
  String get aiPreferFast => '高速なモデルを使う';

  @override
  String get aiPreferFastBody => '答えが早く返り、たいていは短めになります。';

  @override
  String get aiModelStorageNote =>
      'モデルはAndroidが管理し、ほかのアプリとも共有されるため、ここから削除することはできません。';

  @override
  String get aiModelAppleNote => 'モデルは Apple Intelligence の一部で、システムが管理します。';

  @override
  String get aiTechnicalDetails => '技術情報';

  @override
  String aiCoreVersion(String version) {
    return 'AICore $version';
  }

  @override
  String get aiCoreMissing => 'この端末にはAICoreがインストールされていません。';

  @override
  String get aiGeneratedLabel => 'この端末で生成 — 誤りを含む可能性があります';

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
  String get listColumns => '列数';

  @override
  String get listColumnsAuto => '自動';

  @override
  String listColumnsCount(int count) {
    return '$count 列';
  }

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
  String get settingsKanaTab => 'かな早見表';

  @override
  String get settingsKanaTabDesc =>
      'かなタブを表示します。かなの練習などは別アプリ MyNihongo!!!!! をご利用ください。';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsSelectItem => '左のリストから項目を選択してください';

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
  String get backupNoBackups => 'バックアップはまだありません';

  @override
  String get backupRestore => '復元';

  @override
  String get backupRestoreConfirm => '選択したデータがバックアップで上書きされます。続行しますか？';

  @override
  String get backupRestored => 'バックアップを復元しました';

  @override
  String get backupRestoreFailed => '復元に失敗しました';

  @override
  String backupRestoreMissingImages(int count) {
    return '復元しましたが、バックアップ画像ストアに$count件の画像が見つかりませんでした';
  }

  @override
  String get backupDeleteConfirm => 'このバックアップを削除しますか？この操作は取り消せません。';

  @override
  String get backupRestoreModules => '復元するモジュールを選択';

  @override
  String get backupSelectAll => 'すべて選択';

  @override
  String get backupFailed => 'バックアップに失敗しました';

  @override
  String get backupAutoBackupDesc => '1日1回自動でバックアップを作成します';

  @override
  String get backupLocalOnlyNote =>
      'バックアップはこのデバイスにのみ保存されます。クラウドバックアップにはWebDAV同期を使用してください。';

  @override
  String get backupModuleAnime => 'アニメデータ';

  @override
  String get backupCorrupt => '破損';

  @override
  String get backupRestoredSyncDisabled =>
      'バックアップを復元しました。復元したデータを保護するため、自動同期を無効にしました。';

  @override
  String get backupForceUploadPrompt =>
      '復元したデータを今すぐWebDAVにアップロードしますか？リモートのデータは復元したローカルデータで上書きされます。';

  @override
  String get backupForceUploadSkip => '後で';

  @override
  String get backupForceUploadDone => '強制アップロードが完了しました';

  @override
  String get backupForceUploadFailed => '強制アップロードに失敗しました';

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
  String get statsRankingScoreSource => '評価ソース';

  @override
  String get statsRankingScoreSourcePersonal => '自分の評価';

  @override
  String get statsRankingScoreSourceExternal => 'データベース';

  @override
  String get statsRankingExternalSource => 'データベースソース';

  @override
  String get statsRankingExternalAverage => '全ソースの平均';

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
  String get manageFilterArchive => 'ローカル保存';

  @override
  String get manageFilterAll => 'すべて';

  @override
  String get manageFilterArchived => '保存済み';

  @override
  String get manageFilterNotArchived => '未保存';

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

  @override
  String get undo => '元に戻す';

  @override
  String get backupModuleRecommendations => 'おすすめ';

  @override
  String get recommendationsRefresh => '別の候補を表示';

  @override
  String recommendationsRefreshed(int count) {
    return '$count 件をゴミ箱に移しました';
  }

  @override
  String get recommendationsTrash => 'ゴミ箱';

  @override
  String get recommendationsTrashEmpty =>
      'ゴミ箱は空です。「興味なし」にした作品や、更新で見送った作品がここに入ります。';

  @override
  String get recommendationsRestore => '戻す';

  @override
  String get recommendationsRestoreAll => 'すべて戻す';

  @override
  String recommendationsTrashedOn(String date) {
    return '$date に移動';
  }

  @override
  String get recommendationsTrashSequels => 'ライブラリにない続編';

  @override
  String get relatedTitle => '関連作品';

  @override
  String get relatedEmpty => 'ライブラリに関連する作品はまだありません。';

  @override
  String get relatedRefresh => '別の候補を表示';

  @override
  String relatedTrashTitle(String title) {
    return 'ゴミ箱 · $title';
  }

  @override
  String reasonSharedCategories(String categories) {
    return '同じく$categories';
  }

  @override
  String reasonSharedStudio(String studio) {
    return '同じく $studio 制作';
  }

  @override
  String get reasonRelatedByDatabase => 'データベース上の関連作品';

  @override
  String get reasonSharedTitle => '似たタイトル';

  @override
  String get manageViewQuarter => 'クール別に表示';

  @override
  String get manageViewSeries => 'シリーズ別に表示';

  @override
  String get manageSeriesSort => 'シリーズの並び順';

  @override
  String get manageSeriesSortLatest => '放送開始が新しい順';

  @override
  String get manageSeriesSortTitle => 'タイトル';

  @override
  String get manageSeriesSortModified => '最近編集した順';

  @override
  String manageSeriesMembers(int count, int completed) {
    return '$count 作品 · 視聴済み $completed';
  }
}
