// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MyAnime!!!!!';

  @override
  String get navHome => '首页';

  @override
  String get navManage => '管理';

  @override
  String get navStats => '统计';

  @override
  String get navKana => '五十音';

  @override
  String get navSettings => '设置';

  @override
  String homeAiringOn(String date) {
    return '$date 播出';
  }

  @override
  String homeUnwatched(int animeCount, int episodeCount) {
    return '未看番剧 $animeCount 部，$episodeCount 话';
  }

  @override
  String get homeEmpty => '还没有番剧，添加一部开始追番吧！';

  @override
  String get homeCalendarTimeNoteJst => '日历日期使用日本时间（UTC+9）';

  @override
  String get homeCalendarTimeNoteLocal => '日历日期使用设备本地时间；番剧播出时间仍按日本时间计算';

  @override
  String get calendarFormatMonth => '月视图';

  @override
  String get calendarFormatTwoWeeks => '两周';

  @override
  String get calendarFormatWeek => '周';

  @override
  String get animeTitle => '标题';

  @override
  String get animeTitleJa => '日文标题';

  @override
  String get animeSeason => '季度';

  @override
  String get animeStartEp => '起始集';

  @override
  String get animeEndEp => '结束集';

  @override
  String get animeType => '类型';

  @override
  String get animeTypeAuto => '自动';

  @override
  String get animeTypeSingleCour => '单季';

  @override
  String get animeTypeHalfYear => '半年番';

  @override
  String get animeTypeFullYear => '年番';

  @override
  String get animeTypeLongRunning => '长期连载';

  @override
  String get animeTypeAllAtOnce => '一次放出';

  @override
  String get animeAirDay => '播出日';

  @override
  String get animeAirTime => '播出时间';

  @override
  String get animeAirTimeHelper => '日本时间，支持25:00格式';

  @override
  String get animeFirstAirDate => '首播日期';

  @override
  String get animeNotes => '备注';

  @override
  String get animeWatchUrl => '观看链接';

  @override
  String get animeInfoUrl => '信息链接';

  @override
  String get animeOpenUrl => '观看';

  @override
  String get animeOpenInfoUrl => '信息';

  @override
  String get animeRating => '评分';

  @override
  String get animeRatingOverall => '综合';

  @override
  String get animeRatingVisual => '画面/演出';

  @override
  String get animeRatingStory => '剧情';

  @override
  String get animeRatingCharacter => '角色';

  @override
  String get animeRatingMusic => '音乐/音效';

  @override
  String get animeRatingEnjoyment => '观感/推荐度';

  @override
  String get animeRatingAutoHint => '可选，0-10分；综合评分可由子项自动平均。';

  @override
  String get animeRatingOverallHelper => '留空时按子项平均计算';

  @override
  String get animeRatingInvalid => '请输入0到10之间的评分';

  @override
  String get animeRatingManualOverall => '手动综合评分';

  @override
  String get animeRatingAutoOverall => '综合评分由子项平均计算';

  @override
  String get animeLocalArchive => '本地存档';

  @override
  String get animeLocalArchiveHint => '选填。是否保留了本地下载资源。';

  @override
  String get animeLocalArchiveArchived => '已下载到本地';

  @override
  String get animeLocalArchiveNone => '未下载';

  @override
  String get animeArchiveSource => '片源';

  @override
  String get animeArchiveResolution => '分辨率';

  @override
  String get animeArchiveOther => '其他';

  @override
  String get animeArchiveCopies => '存档份数';

  @override
  String get animeArchiveCopiesInvalid => '请输入正整数';

  @override
  String animeArchiveCopiesValue(int count) {
    return '×$count';
  }

  @override
  String get animeArchiveLocation => '资料仓库代码或位置';

  @override
  String get animeArchiveLocationHint => '例如 NAS-01、HDD-C3';

  @override
  String get searchAnimeInfo => '搜索番剧信息';

  @override
  String get searchHint => '输入标题搜索…';

  @override
  String get searchButton => '搜索';

  @override
  String get searchNoResults => '未找到结果';

  @override
  String searchCoverFetchFailed(String error) {
    return '封面获取失败: $error';
  }

  @override
  String get searchCoverImage => '封面图';

  @override
  String get searchFetchCover => '获取';

  @override
  String get searchCurrent => '当前';

  @override
  String get searchFetched => '获取到';

  @override
  String get searchApply => '应用';

  @override
  String get searchWatchUrl => '从 anime1.me 搜索观看链接';

  @override
  String get searchWatchUrlSet => '已填入观看链接';

  @override
  String get searchWatchUrlTitle => '搜索观看链接';

  @override
  String get searchWatchUrlEmpty => '未找到匹配的观看链接';

  @override
  String get searchSort => '排序';

  @override
  String get searchSortRelevance => '相关度';

  @override
  String get searchSortAirDate => '首播日期';

  @override
  String get searchSortEpisodes => '集数';

  @override
  String get searchSortSource => '来源';

  @override
  String get searchFilter => '过滤';

  @override
  String get searchFilterSources => '来源';

  @override
  String get searchFilterWithCover => '仅显示有封面的结果';

  @override
  String get searchFilterWithAirDate => '仅显示有播出日期的结果';

  @override
  String get searchFilterReset => '重置过滤条件';

  @override
  String get searchGroupBySource => '按来源分组';

  @override
  String searchResultCount(int shown, int total) {
    return '共 $total 条，显示 $shown 条';
  }

  @override
  String get searchNoMatchingResults => '没有符合当前过滤条件的结果';

  @override
  String get searchDetailsTitle => '结果详情';

  @override
  String get searchAllTitles => '全部名称';

  @override
  String get searchDetailsHint => '长按结果可查看完整名称与详细信息';

  @override
  String get searchExternalMeta => '资料库信息';

  @override
  String searchExternalMetaValue(int count, String source) {
    return '来自 $source 的 $count 项信息';
  }

  @override
  String searchProgressRound1(int done, int total) {
    return '正在搜索来源 $done / $total…';
  }

  @override
  String searchProgressRound2(int done, int total) {
    return '跨语言补搜 $done / $total…';
  }

  @override
  String get searchSourceFailed => '失败';

  @override
  String searchSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
      zero: '无结果',
    );
    return '$_temp0';
  }

  @override
  String get animeStudios => '制作公司';

  @override
  String get animeGenres => '类型标签';

  @override
  String get animeFormat => '作品形式';

  @override
  String get animeStatus => '播出状态';

  @override
  String get animeDuration => '单集时长';

  @override
  String animeDurationValue(int minutes) {
    return '$minutes 分钟/集';
  }

  @override
  String get animeEndDate => '完结日期';

  @override
  String get animeAlternateTitles => '别名';

  @override
  String get animeExternalMeta => '资料库信息';

  @override
  String get animeExternalRatings => '外部评分';

  @override
  String animeExternalVotes(int votes) {
    return '$votes 人评分';
  }

  @override
  String animeExternalRank(int rank) {
    return '排名 #$rank';
  }

  @override
  String get animeRefreshMeta => '刷新资料库信息';

  @override
  String get animeRefreshMetaDone => '资料库信息已更新';

  @override
  String animeRefreshMetaFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String get animeRefreshMetaNone => '没有可用于刷新的来源页面';

  @override
  String animeRefreshedAt(String date) {
    return '更新于 $date';
  }

  @override
  String get metaUpdatesTitle => '可用更新';

  @override
  String get metaUpdatesTooltip => '可用更新';

  @override
  String get metaUpdatesEmpty => '暂无可用更新';

  @override
  String get metaUpdatesEmptyHint => '资料不全的记录会在后台自动查找。';

  @override
  String metaUpdatesCount(int count) {
    return '$count 条可用';
  }

  @override
  String get metaUpdatesApply => '应用';

  @override
  String get metaUpdatesDismiss => '忽略';

  @override
  String get metaUpdatesApplyPage => '更新本页';

  @override
  String get metaUpdatesApplyAll => '全部更新';

  @override
  String get metaUpdatesConfirmTitle => '确认更新';

  @override
  String metaUpdatesConfirmPage(int count) {
    return '应用本页的 $count 条更新？';
  }

  @override
  String metaUpdatesConfirmAll(int count) {
    return '应用全部 $count 条更新？';
  }

  @override
  String metaUpdatesConfirmAgain(int count) {
    return '这会一次修改 $count 条记录，确定应用？';
  }

  @override
  String metaUpdatesApplied(int count) {
    return '已更新 $count 条记录';
  }

  @override
  String get metaUpdatesManualPick => '需要手动选择';

  @override
  String get metaUpdatesManualPickHint => '没有足够可靠的匹配，请打开该记录手动搜索。';

  @override
  String metaUpdatesExcludedManual(int count) {
    return '已排除 $count 条需要手动选择的记录';
  }

  @override
  String get metaUpdatesCurrent => '当前';

  @override
  String get metaUpdatesProposed => '更新为';

  @override
  String get metaUpdatesEmptyValue => '（空）';

  @override
  String metaUpdatesFrom(String source) {
    return '来自 $source';
  }

  @override
  String metaUpdatesMatch(int percent) {
    return '匹配度 $percent%';
  }

  @override
  String get metaUpdatesNothingSelected => '请至少选择一个字段';

  @override
  String get metaUpdatesScan => '检查更新';

  @override
  String get metaUpdatesScanStop => '停止检查';

  @override
  String metaUpdatesScanProgress(int done, int total) {
    return '已检查 $done / $total';
  }

  @override
  String metaUpdatesScanFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已找到 $count 项',
      zero: '暂未发现',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '检查完成，找到 $count 项可用更新',
      zero: '检查完成，未发现可用更新',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已停止检查，找到 $count 项可用更新',
      zero: '已停止检查，未发现可用更新',
    );
    return '$_temp0';
  }

  @override
  String get metaUpdatesScanUpToDate => '所有资料都已是最新';

  @override
  String get metaUpdatesScanOffline => '当前没有网络连接';

  @override
  String get metaUpdatesManualSearch => '手动搜索';

  @override
  String get settingsMetaAutoUpdate => '后台更新资料库信息';

  @override
  String get settingsMetaAutoUpdateDesc =>
      '应用打开时，自动刷新已保存的资料库信息，并为资料不全的记录查找在线资料。';

  @override
  String get settingsMetaPolicyOff => '关闭';

  @override
  String get settingsMetaPolicyNoCellular => '不使用蜂窝数据';

  @override
  String get settingsMetaPolicyAlways => '任何网络';

  @override
  String get settingsMetaPolicyHint => '只能识别链路类型，无法判断是否计费——手机热点同样会被识别为 Wi-Fi。';

  @override
  String get settingsMetaPrefetchCovers => '预下载封面图';

  @override
  String get settingsMetaPrefetchCoversDesc => '默认关闭。封面是这份缓存里唯一的大体积数据，其余均为纯文字。';

  @override
  String get copyAction => '复制';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get animeEpisodes => '集';

  @override
  String get animeEpisodeList => '剧集列表';

  @override
  String animeEpisodeShort(int ep) {
    return '第$ep集';
  }

  @override
  String get animeAdd => '添加番剧';

  @override
  String get animeEdit => '编辑番剧';

  @override
  String get animeSearchHint => '搜索番剧…';

  @override
  String get animeNoResults => '本季暂无番剧';

  @override
  String get animeFieldRequired => '必填';

  @override
  String animeMissingFields(String fields) {
    return '请填写以下字段：$fields';
  }

  @override
  String get animeWatched => '已看';

  @override
  String get animeUnwatched => '未看';

  @override
  String get animeSkipped => '跳过';

  @override
  String get animeShiftForward => '向前移动一周（本集及之后）';

  @override
  String get animeShiftBackward => '向后移动一周（本集及之后）';

  @override
  String get animeMarkAllWatched => '全部已看';

  @override
  String get animeMarkAllUnwatched => '全部取消';

  @override
  String get animeResetSchedule => '重置日程';

  @override
  String get animeResetScheduleConfirm => '将所有集数的日期调整重置为按首播日期计算的原始日程？';

  @override
  String get animeAbandon => '放弃番剧';

  @override
  String get animeResume => '继续追番';

  @override
  String get animePrevSeason => '上一季';

  @override
  String get animeNextSeason => '下一季';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get commonDelete => '确认删除';

  @override
  String commonDeleteConfirm(String item) {
    return '删除「$item」？';
  }

  @override
  String get commonDontAskMinutes => '5分钟内不再询问';

  @override
  String get commonCancel => '取消';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsHomeCalendarLayout => '首页日历样式';

  @override
  String get settingsHomeCalendarLayoutLocal => '本地';

  @override
  String get settingsHomeCalendarLayoutJapanese => '日本（日月火水木金土）';

  @override
  String get settingsWeekStartDay => '每周开始于';

  @override
  String get settingsWeekStartLockedJapanese => '日本日历固定从周日开始';

  @override
  String get settingsHomeCalendarTimeBasis => '首页日历时间';

  @override
  String get settingsHomeCalendarTimeBasisJst => '日本时间';

  @override
  String get settingsHomeCalendarTimeBasisLocal => '本地时间';

  @override
  String get settingsHomeCalendarTimeBasisDesc => '番剧播出时间仍按日本时间计算。';

  @override
  String get settingsReminder => '每日提醒';

  @override
  String get settingsReminderOff => '已关闭';

  @override
  String get settingsReminderTime => '提醒时间';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacyPolicy => '隐私政策';

  @override
  String get settingsLicense => '许可证 (GPLv3)';

  @override
  String get settingsLicenses => '开源许可证';

  @override
  String get settingsConfirm => '确认';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVServerURL => '服务器地址';

  @override
  String get settingsWebDAVUsername => '用户名';

  @override
  String get settingsWebDAVPassword => '密码';

  @override
  String get settingsWebDAVRemotePath => '远程路径';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud 预设';

  @override
  String get settingsWebDAVTestConnection => '测试连接';

  @override
  String get settingsWebDAVAutoSync => '自动同步';

  @override
  String get settingsWebDAVAutoSyncDesc => '编辑后和应用恢复时自动同步';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVDisconnect => '断开连接';

  @override
  String get settingsWebDAVConfigSaved => '配置已保存';

  @override
  String get settingsWebDAVConfigRemoved => '配置已移除';

  @override
  String get settingsWebDAVConnectionSuccess => '连接成功';

  @override
  String get settingsWebDAVConnectionFailed => '连接失败';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String get settingsWebDAVSyncFailed => '同步失败';

  @override
  String get settingsWebDAVAutoSyncFailed => '自动同步失败';

  @override
  String get settingsWebDAVAutoSyncConflict => '自动同步发现冲突';

  @override
  String get settingsWebDAVLastSuccess => '上次成功同步';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同步完成，但$count张封面传输失败';
  }

  @override
  String get settingsWebDAVForceUpload => '强制上传';

  @override
  String get settingsWebDAVForceDownload => '强制下载';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => '确认强制上传？';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      '将用本地数据和图片覆盖远程内容。上次同步后远程的更改将丢失。';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => '确认强制下载？';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      '将用远程数据和图片替换本地内容。上次同步后本地的更改将丢失。';

  @override
  String get syncPhaseConnecting => '正在连接…';

  @override
  String syncPhaseDownloadingData(String file, int current, int total) {
    return '正在下载 $file（$current/$total）';
  }

  @override
  String syncPhaseMerging(String file) {
    return '正在合并 $file…';
  }

  @override
  String syncPhaseUploadingData(String file) {
    return '正在上传 $file…';
  }

  @override
  String syncPhaseUploadingImages(int current, int total) {
    return '正在上传图片（$current/$total）';
  }

  @override
  String syncPhaseDownloadingImages(int current, int total) {
    return '正在下载图片（$current/$total）';
  }

  @override
  String get commonOk => '确定';

  @override
  String get backupTitle => '备份';

  @override
  String get backupSubtitle => '完整本机备份（数据 + 图片）';

  @override
  String get backupCreate => '创建备份';

  @override
  String get backupCreated => '备份已创建';

  @override
  String get backupAutoBackup => '自动备份';

  @override
  String get backupRetention => '保留期限';

  @override
  String get backupKeepForever => '永久保留';

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String backupHistory(int count) {
    return '历史记录 ($count)';
  }

  @override
  String get backupNoBackups => '暂无备份';

  @override
  String get backupRestore => '还原';

  @override
  String get backupRestoreConfirm => '这将使用备份覆盖所选数据，是否继续？';

  @override
  String get backupRestored => '备份已还原';

  @override
  String get backupRestoreFailed => '还原失败';

  @override
  String backupRestoreMissingImages(int count) {
    return '已还原，但备份图片存储中缺少 $count 张图片';
  }

  @override
  String get backupDeleteConfirm => '删除此备份？此操作无法撤销。';

  @override
  String get backupRestoreModules => '选择要还原的模块';

  @override
  String get backupSelectAll => '全选';

  @override
  String get backupFailed => '备份失败';

  @override
  String get backupAutoBackupDesc => '每天自动创建一次备份';

  @override
  String get backupLocalOnlyNote => '备份仅存储在本设备上。云端备份请使用 WebDAV 同步。';

  @override
  String get backupModuleAnime => '动画数据';

  @override
  String get backupCorrupt => '已损坏';

  @override
  String get backupRestoredSyncDisabled => '备份已还原。为保护还原的数据，已停用自动同步。';

  @override
  String get backupForceUploadPrompt =>
      '现在将还原的数据上传到 WebDAV 吗？远程数据将被还原后的本地数据覆盖。';

  @override
  String get backupForceUploadSkip => '暂不';

  @override
  String get backupForceUploadDone => '强制上传完成';

  @override
  String get backupForceUploadFailed => '强制上传失败';

  @override
  String get exportData => '导出数据';

  @override
  String get importData => '导入数据';

  @override
  String get exportSuccess => '数据导出成功';

  @override
  String get importSuccess => '数据导入成功';

  @override
  String get importFailed => '导入失败';

  @override
  String get importConfirm => '这将覆盖当前数据，确定继续？';

  @override
  String get settingsStorageLocation => '存储位置';

  @override
  String get settingsStoragePathHint => '输入自定义数据存储目录路径，留空使用默认位置。';

  @override
  String get settingsDirectoryPath => '目录路径';

  @override
  String get settingsResetDefault => '恢复默认';

  @override
  String get settingsResetDefaultLocation => '存储位置已恢复默认';

  @override
  String get settingsStoragePathUpdated => '存储位置已更新';

  @override
  String get dataMigration => '打开数据目录';

  @override
  String get dataMigrationDesc => '打开应用数据文件夹';

  @override
  String get homeCalendarJst => '日历日期为 JST（日本标准时间 UTC+9）';

  @override
  String get animeShare => '分享';

  @override
  String get shareCopied => '图片已复制到剪贴板';

  @override
  String get shareCopy => '复制';

  @override
  String get shareSaveAs => '另存为';

  @override
  String get shareSaveAll => '全部保存';

  @override
  String sharePagesLabel(int count) {
    return '$count 页';
  }

  @override
  String get shareSaved => '图片已保存';

  @override
  String get shareFailed => '分享失败';

  @override
  String get shareUrlOptions => '包含链接';

  @override
  String get statsTitle => '统计';

  @override
  String get statsQuarter => '季度';

  @override
  String get statsYear => '年度';

  @override
  String get statsAll => '全部';

  @override
  String get statsTracked => '追番';

  @override
  String get statsCompleted => '看完';

  @override
  String get statsDropped => '放弃';

  @override
  String get statsWatching => '在追';

  @override
  String get statsNotStarted => '未开始';

  @override
  String get statsTrend => '趋势';

  @override
  String get statsRanking => '排行';

  @override
  String get statsRankingFilters => '筛选';

  @override
  String get statsRankingTimeFilter => '时间';

  @override
  String get statsRankingTypeFilter => '类型';

  @override
  String get statsRankingAllTypes => '全部类型';

  @override
  String get statsRankingSortBy => '排序依据';

  @override
  String get statsRankingScoreSource => '评分来源';

  @override
  String get statsRankingScoreSourcePersonal => '我的评分';

  @override
  String get statsRankingScoreSourceExternal => '资料库';

  @override
  String get statsRankingExternalSource => '资料库来源';

  @override
  String get statsRankingExternalAverage => '所有来源平均';

  @override
  String get statsRankingDescending => '从高到低';

  @override
  String get statsRankingAscending => '从低到高';

  @override
  String get statsRankingDescShort => '降序';

  @override
  String get statsRankingAscShort => '升序';

  @override
  String get statsRankingCustomRange => '自定义范围';

  @override
  String get statsRankingSelectYear => '选择年度';

  @override
  String get statsRankingStartQuarter => '开始季度';

  @override
  String get statsRankingEndQuarter => '结束季度';

  @override
  String get statsRankingEmpty => '没有符合筛选条件的已评分番剧';

  @override
  String statsRankingCount(int count) {
    return '$count 部已评分番剧';
  }

  @override
  String get manageJumpToQuarter => '跳转到季度';

  @override
  String get manageNoSearchResults => '没有匹配的番剧';

  @override
  String get manageFilterArchive => '本地存档';

  @override
  String get manageFilterAll => '全部';

  @override
  String get manageFilterArchived => '已存档';

  @override
  String get manageFilterNotArchived => '未存档';

  @override
  String get manageOther => '其他';

  @override
  String get dayMon => '周一';

  @override
  String get dayTue => '周二';

  @override
  String get dayWed => '周三';

  @override
  String get dayThu => '周四';

  @override
  String get dayFri => '周五';

  @override
  String get daySat => '周六';

  @override
  String get daySun => '周日';

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
    return '今日放送 $animeCount 部番剧，$episodeCount 话';
  }

  @override
  String reminderUnwatched(int animeCount, int episodeCount) {
    return '待看 $animeCount 部番剧，$episodeCount 话';
  }

  @override
  String syncConflictTitle(String name) {
    return '同步冲突: $name';
  }

  @override
  String get syncConflictDesc => '该番剧在上次同步后在两台设备上均被修改。';

  @override
  String get syncLocalVersion => '本地版本:';

  @override
  String get syncRemoteVersion => '远程版本:';

  @override
  String syncModifiedAt(String time) {
    return '修改时间: $time';
  }

  @override
  String syncEpisodeRange(int start, int end) {
    return '集数: $start〜$end';
  }

  @override
  String syncWatched(int count) {
    return '已观看: $count';
  }

  @override
  String get syncKeepLocal => '保留本地';

  @override
  String get syncKeepRemote => '保留远程';

  @override
  String searchEpisodesCount(int count) {
    return '$count话';
  }

  @override
  String get animeSeasonHint => '第1季';

  @override
  String get shareTypeTitle => '分享方式';

  @override
  String get shareAsImage => '分享为图片';

  @override
  String get shareAsData => '分享为数据文件';

  @override
  String get shareAsTxt => '导出为 TXT（仅名称）';

  @override
  String get statsShareTxtEmpty => '没有可导出的番剧';

  @override
  String get importAnimeSuccess => '番剧导入成功';

  @override
  String get importAnimeFailed => '导入失败';

  @override
  String get statsShare => '分享统计';

  @override
  String statsShareSummary(String scope, int count) {
    return '$scope · $count 部番剧';
  }

  @override
  String get importBundleTitle => '导入番剧';

  @override
  String importBundleCount(int count) {
    return '文件中找到 $count 部番剧';
  }

  @override
  String importBundleConflictTitle(String name) {
    return '导入冲突: $name';
  }

  @override
  String get importBundleConflictDesc => '这部番剧已存在于你的资料库中。';

  @override
  String get importBundleLocalVersion => '本地版本:';

  @override
  String get importBundleImportedVersion => '导入版本:';

  @override
  String get importBundleKeepLocal => '保留本地';

  @override
  String get importBundleKeepImport => '使用导入';

  @override
  String get importBundleMerge => '合并';

  @override
  String importBundleSuccess(int count) {
    return '成功导入 $count 部番剧';
  }

  @override
  String get importBundleNoConflicts => '未发现冲突，正在导入全部…';

  @override
  String get settingsDuplicateCheck => '检查重复';

  @override
  String get settingsDuplicateCheckDesc => '查找并合并重复的番剧记录';

  @override
  String get duplicateCheckTitle => '重复检查';

  @override
  String get duplicateCheckEmpty => '未发现重复';

  @override
  String duplicateCheckFound(int count) {
    return '发现 $count 组重复';
  }

  @override
  String get duplicateReasonSameId => '相同 ID';

  @override
  String get duplicateReasonSameUrl => '相同链接';

  @override
  String get duplicateReasonSameTitleSeason => '相同标题/季度';

  @override
  String duplicateGroupLabel(int index, int total, String reason) {
    return '第 $index/$total 组: $reason';
  }

  @override
  String get duplicateKeepFirst => '保留此项';

  @override
  String get duplicateMergeAll => '全部合并到此';

  @override
  String get duplicateDeleteOthers => '删除其他项';

  @override
  String get duplicateResolved => '重复已成功解决';

  @override
  String get duplicateResolveConfirm => '解决此重复组？';

  @override
  String get addAnimeCreate => '新建番剧';

  @override
  String get addAnimeImport => '从文件导入';

  @override
  String get exportAsZip => '导出为 ZIP';

  @override
  String get exportAsZipDesc => '完整数据压缩包（番剧数据 + 封面图片），用于备份或迁移';

  @override
  String get exportAsMarkdown => '导出为 Markdown';

  @override
  String get exportAsMarkdownDesc => '按开播时间排列的番剧列表及观看状态，用于 LLM 个性化学习';

  @override
  String get trayShow => '显示';

  @override
  String get trayQuit => '退出';

  @override
  String get settingsMinimizeToTray => '最小化到托盘';

  @override
  String get settingsCloseToTray => '关闭到托盘';

  @override
  String get settingsAutoStart => '开机自启';

  @override
  String get settingsApiServer => 'API 服务器设置';

  @override
  String get settingsApiEnabled => '本地 API 服务器';

  @override
  String get settingsApiListenAddress => '监听地址';

  @override
  String get settingsApiPort => '端口';

  @override
  String get settingsApiUsername => '用户名';

  @override
  String get settingsApiPassword => '密码';

  @override
  String settingsApiRunning(int port) {
    return '运行中，端口 $port';
  }

  @override
  String get settingsApiStopped => '已停止';

  @override
  String get settingsApiNeedCredentials => '监听非 localhost 时需设置用户名和密码';

  @override
  String get settingsApiRestart => '重启服务器';

  @override
  String settingsApiRestarted(int port) {
    return 'API 服务器已在端口 $port 重启';
  }

  @override
  String get kanaTitle => '五十音速查';

  @override
  String get kanaScriptHiragana => '平假名';

  @override
  String get kanaScriptKatakana => '片假名';

  @override
  String get kanaSearchHint => '搜索假名或罗马音…';

  @override
  String kanaSearchResults(int count) {
    return '匹配 ($count)';
  }

  @override
  String get kanaNoMatches => '没有匹配的假名';

  @override
  String get kanaBasicSection => '清音五十音';

  @override
  String get kanaVoicedSection => '浊音 / 半浊音';

  @override
  String get kanaYoonSection => '拗音';

  @override
  String get kanaRulesSection => '发音规则';

  @override
  String get kanaRuleMoraTitle => '一个假名一拍';

  @override
  String get kanaRuleMoraBody => '每个假名占一个 mora。像 ka-ki-ku-ke-ko 一样保持均匀节奏。';

  @override
  String get kanaRuleVowelsTitle => '元音稳定';

  @override
  String get kanaRuleVowelsBody => 'a, i, u, e, o 要短而清楚，不像英语弱读元音那样被吞掉。';

  @override
  String get kanaRuleDakutenTitle => '浊音与半浊音';

  @override
  String get kanaRuleDakutenBody => '゛让辅音浊化: k 变 g，s 变 z，t 变 d，h 变 b。゜让 h 变 p。';

  @override
  String get kanaRuleYoonTitle => '拗音组合';

  @override
  String get kanaRuleYoonBody => '小写 ゃ/ゅ/ょ 与 i 段假名合并: き + ゃ = きゃ kya。';

  @override
  String get kanaRuleSokuonTitle => '促音';

  @override
  String get kanaRuleSokuonBody => '小写 っ/ッ 表示下一个辅音前有短暂停顿，并双写辅音，如 まって matte。';

  @override
  String get kanaRuleLongVowelsTitle => '长音';

  @override
  String get kanaRuleLongVowelsBody => 'ー 延长片假名音。平假名里 おう 常读长 o，えい 常读长 e。';

  @override
  String get kanaRuleNTitle => 'ん / ン';

  @override
  String get kanaRuleNBody => '通常读 n；在 m, b, p 前接近 m，在 k, g 前会变成较轻的鼻音。';

  @override
  String get statsShareStatusTitle => '包含的状态';

  @override
  String get statsShareStatusHint => '选择要包含的观看状态';

  @override
  String get statsShareLimitTitle => '大量图片分享';

  @override
  String statsShareLimitWarning(int count) {
    return '共 $count 部，生成可能耗时较长。';
  }

  @override
  String get statsShareLimitEnable => '设置条目上限';

  @override
  String get statsShareLimitCount => '上限';

  @override
  String get statsShareLimitPriority => '优先顺序';

  @override
  String get statsSharePriorityRecent => '时间近（首播日）';

  @override
  String get statsSharePriorityOldest => '时间远（首播日）';

  @override
  String get statsShareGenerating => '正在生成图片，可能耗时较长…';

  @override
  String statsShareGeneratingProgress(int done, int total) {
    return '加载封面: $done/$total';
  }

  @override
  String statsShareTruncated(int shown, int total) {
    return '$shown/$total 部（已截断）';
  }

  @override
  String get settingsDesktop => '桌面';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'MyAnime!!!!!';

  @override
  String get navHome => '首頁';

  @override
  String get navManage => '管理';

  @override
  String get navStats => '統計';

  @override
  String get navKana => '五十音';

  @override
  String get navSettings => '設定';

  @override
  String homeAiringOn(String date) {
    return '$date 播出';
  }

  @override
  String homeUnwatched(int animeCount, int episodeCount) {
    return '未看番劇 $animeCount 部，$episodeCount 話';
  }

  @override
  String get homeEmpty => '還沒有番劇，新增一部開始追番吧！';

  @override
  String get homeCalendarTimeNoteJst => '日曆日期使用日本時間（UTC+9）';

  @override
  String get homeCalendarTimeNoteLocal => '日曆日期使用裝置本地時間；番劇播出時間仍按日本時間計算';

  @override
  String get calendarFormatMonth => '月檢視';

  @override
  String get calendarFormatTwoWeeks => '兩週';

  @override
  String get calendarFormatWeek => '週';

  @override
  String get animeTitle => '標題';

  @override
  String get animeTitleJa => '日文標題';

  @override
  String get animeSeason => '季度';

  @override
  String get animeStartEp => '起始集';

  @override
  String get animeEndEp => '結束集';

  @override
  String get animeType => '類型';

  @override
  String get animeTypeAuto => '自動';

  @override
  String get animeTypeSingleCour => '單季';

  @override
  String get animeTypeHalfYear => '半年番';

  @override
  String get animeTypeFullYear => '年番';

  @override
  String get animeTypeLongRunning => '長期連載';

  @override
  String get animeTypeAllAtOnce => '一次放出';

  @override
  String get animeAirDay => '播出日';

  @override
  String get animeAirTime => '播出時間';

  @override
  String get animeAirTimeHelper => '日本時間，支援25:00格式';

  @override
  String get animeFirstAirDate => '首播日期';

  @override
  String get animeNotes => '備註';

  @override
  String get animeWatchUrl => '觀看連結';

  @override
  String get animeInfoUrl => '資訊連結';

  @override
  String get animeOpenUrl => '觀看';

  @override
  String get animeOpenInfoUrl => '資訊';

  @override
  String get animeRating => '評分';

  @override
  String get animeRatingOverall => '綜合';

  @override
  String get animeRatingVisual => '畫面/演出';

  @override
  String get animeRatingStory => '劇情';

  @override
  String get animeRatingCharacter => '角色';

  @override
  String get animeRatingMusic => '音樂/音效';

  @override
  String get animeRatingEnjoyment => '觀感/推薦度';

  @override
  String get animeRatingAutoHint => '可選，0-10分；綜合評分可由子項自動平均。';

  @override
  String get animeRatingOverallHelper => '留空時按子項平均計算';

  @override
  String get animeRatingInvalid => '請輸入0到10之間的評分';

  @override
  String get animeRatingManualOverall => '手動綜合評分';

  @override
  String get animeRatingAutoOverall => '綜合評分由子項平均計算';

  @override
  String get animeLocalArchive => '本機存檔';

  @override
  String get animeLocalArchiveHint => '選填。是否保留了本機下載資源。';

  @override
  String get animeLocalArchiveArchived => '已下載到本機';

  @override
  String get animeLocalArchiveNone => '未下載';

  @override
  String get animeArchiveSource => '片源';

  @override
  String get animeArchiveResolution => '解析度';

  @override
  String get animeArchiveOther => '其他';

  @override
  String get animeArchiveCopies => '存檔份數';

  @override
  String get animeArchiveCopiesInvalid => '請輸入正整數';

  @override
  String animeArchiveCopiesValue(int count) {
    return '×$count';
  }

  @override
  String get animeArchiveLocation => '資料倉庫代碼或位置';

  @override
  String get animeArchiveLocationHint => '例如 NAS-01、HDD-C3';

  @override
  String get searchAnimeInfo => '搜尋番劇資訊';

  @override
  String get searchHint => '輸入標題搜尋…';

  @override
  String get searchButton => '搜尋';

  @override
  String get searchNoResults => '未找到結果';

  @override
  String searchCoverFetchFailed(String error) {
    return '封面取得失敗: $error';
  }

  @override
  String get searchCoverImage => '封面圖';

  @override
  String get searchFetchCover => '獲取';

  @override
  String get searchCurrent => '當前';

  @override
  String get searchFetched => '獲取到';

  @override
  String get searchApply => '套用';

  @override
  String get searchWatchUrl => '從 anime1.me 搜尋觀看連結';

  @override
  String get searchWatchUrlSet => '已填入觀看連結';

  @override
  String get searchWatchUrlTitle => '搜尋觀看連結';

  @override
  String get searchWatchUrlEmpty => '未找到匹配的觀看連結';

  @override
  String get searchSort => '排序';

  @override
  String get searchSortRelevance => '相關度';

  @override
  String get searchSortAirDate => '首播日期';

  @override
  String get searchSortEpisodes => '集數';

  @override
  String get searchSortSource => '來源';

  @override
  String get searchFilter => '過濾';

  @override
  String get searchFilterSources => '來源';

  @override
  String get searchFilterWithCover => '僅顯示有封面的結果';

  @override
  String get searchFilterWithAirDate => '僅顯示有播出日期的結果';

  @override
  String get searchFilterReset => '重設過濾條件';

  @override
  String get searchGroupBySource => '依來源分組';

  @override
  String searchResultCount(int shown, int total) {
    return '共 $total 筆，顯示 $shown 筆';
  }

  @override
  String get searchNoMatchingResults => '沒有符合目前過濾條件的結果';

  @override
  String get searchDetailsTitle => '結果詳情';

  @override
  String get searchAllTitles => '全部名稱';

  @override
  String get searchDetailsHint => '長按結果可檢視完整名稱與詳細資訊';

  @override
  String get searchExternalMeta => '資料庫資訊';

  @override
  String searchExternalMetaValue(int count, String source) {
    return '來自 $source 的 $count 項資訊';
  }

  @override
  String searchProgressRound1(int done, int total) {
    return '正在搜尋來源 $done / $total…';
  }

  @override
  String searchProgressRound2(int done, int total) {
    return '跨語言補搜 $done / $total…';
  }

  @override
  String get searchSourceFailed => '失敗';

  @override
  String searchSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 筆',
      zero: '無結果',
    );
    return '$_temp0';
  }

  @override
  String get animeStudios => '製作公司';

  @override
  String get animeGenres => '類型標籤';

  @override
  String get animeFormat => '作品形式';

  @override
  String get animeStatus => '播出狀態';

  @override
  String get animeDuration => '單集時長';

  @override
  String animeDurationValue(int minutes) {
    return '$minutes 分鐘/集';
  }

  @override
  String get animeEndDate => '完結日期';

  @override
  String get animeAlternateTitles => '別名';

  @override
  String get animeExternalMeta => '資料庫資訊';

  @override
  String get animeExternalRatings => '外部評分';

  @override
  String animeExternalVotes(int votes) {
    return '$votes 人評分';
  }

  @override
  String animeExternalRank(int rank) {
    return '排名 #$rank';
  }

  @override
  String get animeRefreshMeta => '重新整理資料庫資訊';

  @override
  String get animeRefreshMetaDone => '資料庫資訊已更新';

  @override
  String animeRefreshMetaFailed(String error) {
    return '重新整理失敗：$error';
  }

  @override
  String get animeRefreshMetaNone => '沒有可用於重新整理的來源頁面';

  @override
  String animeRefreshedAt(String date) {
    return '更新於 $date';
  }

  @override
  String get metaUpdatesTitle => '可用更新';

  @override
  String get metaUpdatesTooltip => '可用更新';

  @override
  String get metaUpdatesEmpty => '暫無可用更新';

  @override
  String get metaUpdatesEmptyHint => '資料不全的記錄會在背景自動尋找。';

  @override
  String metaUpdatesCount(int count) {
    return '$count 筆可用';
  }

  @override
  String get metaUpdatesApply => '套用';

  @override
  String get metaUpdatesDismiss => '忽略';

  @override
  String get metaUpdatesApplyPage => '更新本頁';

  @override
  String get metaUpdatesApplyAll => '全部更新';

  @override
  String get metaUpdatesConfirmTitle => '確認更新';

  @override
  String metaUpdatesConfirmPage(int count) {
    return '套用本頁的 $count 筆更新？';
  }

  @override
  String metaUpdatesConfirmAll(int count) {
    return '套用全部 $count 筆更新？';
  }

  @override
  String metaUpdatesConfirmAgain(int count) {
    return '這會一次修改 $count 筆記錄，確定套用？';
  }

  @override
  String metaUpdatesApplied(int count) {
    return '已更新 $count 筆記錄';
  }

  @override
  String get metaUpdatesManualPick => '需要手動選擇';

  @override
  String get metaUpdatesManualPickHint => '沒有足夠可靠的比對結果，請開啟該記錄手動搜尋。';

  @override
  String metaUpdatesExcludedManual(int count) {
    return '已排除 $count 筆需要手動選擇的記錄';
  }

  @override
  String get metaUpdatesCurrent => '目前';

  @override
  String get metaUpdatesProposed => '更新為';

  @override
  String get metaUpdatesEmptyValue => '（空）';

  @override
  String metaUpdatesFrom(String source) {
    return '來自 $source';
  }

  @override
  String metaUpdatesMatch(int percent) {
    return '相符度 $percent%';
  }

  @override
  String get metaUpdatesNothingSelected => '請至少選擇一個欄位';

  @override
  String get metaUpdatesScan => '檢查更新';

  @override
  String get metaUpdatesScanStop => '停止檢查';

  @override
  String metaUpdatesScanProgress(int done, int total) {
    return '已檢查 $done / $total';
  }

  @override
  String metaUpdatesScanFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已找到 $count 項',
      zero: '暫未發現',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '檢查完成，找到 $count 項可用更新',
      zero: '檢查完成，未發現可用更新',
    );
    return '$_temp0';
  }

  @override
  String metaUpdatesScanCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已停止檢查，找到 $count 項可用更新',
      zero: '已停止檢查，未發現可用更新',
    );
    return '$_temp0';
  }

  @override
  String get metaUpdatesScanUpToDate => '所有資料都已是最新';

  @override
  String get metaUpdatesScanOffline => '目前沒有網路連線';

  @override
  String get metaUpdatesManualSearch => '手動搜尋';

  @override
  String get settingsMetaAutoUpdate => '背景更新資料庫資訊';

  @override
  String get settingsMetaAutoUpdateDesc =>
      '應用程式開啟時，自動重新整理已儲存的資料庫資訊，並為資料不全的記錄尋找線上資料。';

  @override
  String get settingsMetaPolicyOff => '關閉';

  @override
  String get settingsMetaPolicyNoCellular => '不使用行動數據';

  @override
  String get settingsMetaPolicyAlways => '任何網路';

  @override
  String get settingsMetaPolicyHint => '只能辨識連線類型，無法判斷是否計費——手機熱點同樣會被辨識為 Wi-Fi。';

  @override
  String get settingsMetaPrefetchCovers => '預先下載封面圖';

  @override
  String get settingsMetaPrefetchCoversDesc => '預設關閉。封面是這份快取中唯一的大型資料，其餘皆為純文字。';

  @override
  String get copyAction => '複製';

  @override
  String get copiedToClipboard => '已複製到剪貼簿';

  @override
  String get animeEpisodes => '集';

  @override
  String get animeEpisodeList => '劇集列表';

  @override
  String animeEpisodeShort(int ep) {
    return '第$ep集';
  }

  @override
  String get animeAdd => '新增番劇';

  @override
  String get animeEdit => '編輯番劇';

  @override
  String get animeSearchHint => '搜尋番劇…';

  @override
  String get animeNoResults => '本季暫無番劇';

  @override
  String get animeFieldRequired => '必填';

  @override
  String animeMissingFields(String fields) {
    return '請填寫以下欄位：$fields';
  }

  @override
  String get animeWatched => '已看';

  @override
  String get animeUnwatched => '未看';

  @override
  String get animeSkipped => '跳過';

  @override
  String get animeShiftForward => '向前移動一週（本集及之後）';

  @override
  String get animeShiftBackward => '向後移動一週（本集及之後）';

  @override
  String get animeMarkAllWatched => '全部已看';

  @override
  String get animeMarkAllUnwatched => '全部取消';

  @override
  String get animeResetSchedule => '重設日程';

  @override
  String get animeResetScheduleConfirm => '將所有集數的日期調整重設為按首播日期計算的原始日程？';

  @override
  String get animeAbandon => '放棄番劇';

  @override
  String get animeResume => '繼續追番';

  @override
  String get animePrevSeason => '上一季';

  @override
  String get animeNextSeason => '下一季';

  @override
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get commonDelete => '確認刪除';

  @override
  String commonDeleteConfirm(String item) {
    return '刪除「$item」？';
  }

  @override
  String get commonDontAskMinutes => '5分鐘內不再詢問';

  @override
  String get commonCancel => '取消';

  @override
  String get settingsTheme => '主題';

  @override
  String get settingsThemeSystem => '跟隨系統';

  @override
  String get settingsThemeLight => '淺色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsHomeCalendarLayout => '首頁日曆樣式';

  @override
  String get settingsHomeCalendarLayoutLocal => '本地';

  @override
  String get settingsHomeCalendarLayoutJapanese => '日本（日月火水木金土）';

  @override
  String get settingsWeekStartDay => '每週開始於';

  @override
  String get settingsWeekStartLockedJapanese => '日本日曆固定從週日開始';

  @override
  String get settingsHomeCalendarTimeBasis => '首頁日曆時間';

  @override
  String get settingsHomeCalendarTimeBasisJst => '日本時間';

  @override
  String get settingsHomeCalendarTimeBasisLocal => '本地時間';

  @override
  String get settingsHomeCalendarTimeBasisDesc => '番劇播出時間仍按日本時間計算。';

  @override
  String get settingsReminder => '每日提醒';

  @override
  String get settingsReminderOff => '已關閉';

  @override
  String get settingsReminderTime => '提醒時間';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsData => '資料';

  @override
  String get settingsAbout => '關於';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacyPolicy => '隱私政策';

  @override
  String get settingsLicense => '授權條款 (GPLv3)';

  @override
  String get settingsLicenses => '開源授權';

  @override
  String get settingsConfirm => '確認';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVServerURL => '伺服器位址';

  @override
  String get settingsWebDAVUsername => '使用者名稱';

  @override
  String get settingsWebDAVPassword => '密碼';

  @override
  String get settingsWebDAVRemotePath => '遠端路徑';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud 預設';

  @override
  String get settingsWebDAVTestConnection => '測試連線';

  @override
  String get settingsWebDAVAutoSync => '自動同步';

  @override
  String get settingsWebDAVAutoSyncDesc => '編輯後與應用程式恢復時自動同步';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVDisconnect => '中斷連線';

  @override
  String get settingsWebDAVConfigSaved => '設定已儲存';

  @override
  String get settingsWebDAVConfigRemoved => '設定已移除';

  @override
  String get settingsWebDAVConnectionSuccess => '連線成功';

  @override
  String get settingsWebDAVConnectionFailed => '連線失敗';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String get settingsWebDAVSyncFailed => '同步失敗';

  @override
  String get settingsWebDAVAutoSyncFailed => '自動同步失敗';

  @override
  String get settingsWebDAVAutoSyncConflict => '自動同步發現衝突';

  @override
  String get settingsWebDAVLastSuccess => '上次成功同步';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同步完成，但$count張封面傳輸失敗';
  }

  @override
  String get settingsWebDAVForceUpload => '強制上傳';

  @override
  String get settingsWebDAVForceDownload => '強制下載';

  @override
  String get settingsWebDAVForceUploadConfirmTitle => '確認強制上傳？';

  @override
  String get settingsWebDAVForceUploadConfirmBody =>
      '將用本地資料與圖片覆蓋遠端內容。上次同步後遠端的變更將遺失。';

  @override
  String get settingsWebDAVForceDownloadConfirmTitle => '確認強制下載？';

  @override
  String get settingsWebDAVForceDownloadConfirmBody =>
      '將用遠端資料與圖片取代本地內容。上次同步後本地的變更將遺失。';

  @override
  String get syncPhaseConnecting => '正在連線…';

  @override
  String syncPhaseDownloadingData(String file, int current, int total) {
    return '正在下載 $file（$current/$total）';
  }

  @override
  String syncPhaseMerging(String file) {
    return '正在合併 $file…';
  }

  @override
  String syncPhaseUploadingData(String file) {
    return '正在上傳 $file…';
  }

  @override
  String syncPhaseUploadingImages(int current, int total) {
    return '正在上傳圖片（$current/$total）';
  }

  @override
  String syncPhaseDownloadingImages(int current, int total) {
    return '正在下載圖片（$current/$total）';
  }

  @override
  String get commonOk => '確定';

  @override
  String get backupTitle => '備份';

  @override
  String get backupSubtitle => '完整本機備份（資料 + 圖片）';

  @override
  String get backupCreate => '建立備份';

  @override
  String get backupCreated => '備份已建立';

  @override
  String get backupAutoBackup => '自動備份';

  @override
  String get backupRetention => '保留期限';

  @override
  String get backupKeepForever => '永久保留';

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String backupHistory(int count) {
    return '歷史記錄 ($count)';
  }

  @override
  String get backupNoBackups => '暫無備份';

  @override
  String get backupRestore => '還原';

  @override
  String get backupRestoreConfirm => '這將使用備份覆蓋所選資料，是否繼續？';

  @override
  String get backupRestored => '備份已還原';

  @override
  String get backupRestoreFailed => '還原失敗';

  @override
  String backupRestoreMissingImages(int count) {
    return '已還原，但備份圖片儲存中缺少 $count 張圖片';
  }

  @override
  String get backupDeleteConfirm => '刪除此備份？此操作無法復原。';

  @override
  String get backupRestoreModules => '選擇要還原的模組';

  @override
  String get backupSelectAll => '全選';

  @override
  String get backupFailed => '備份失敗';

  @override
  String get backupAutoBackupDesc => '每天自動建立一次備份';

  @override
  String get backupLocalOnlyNote => '備份僅儲存在本裝置上。雲端備份請使用 WebDAV 同步。';

  @override
  String get backupModuleAnime => '動畫資料';

  @override
  String get backupCorrupt => '已損壞';

  @override
  String get backupRestoredSyncDisabled => '備份已還原。為保護還原的資料，已停用自動同步。';

  @override
  String get backupForceUploadPrompt =>
      '現在將還原的資料上傳到 WebDAV 嗎？遠端資料將被還原後的本地資料覆蓋。';

  @override
  String get backupForceUploadSkip => '暫不';

  @override
  String get backupForceUploadDone => '強制上傳完成';

  @override
  String get backupForceUploadFailed => '強制上傳失敗';

  @override
  String get exportData => '匯出資料';

  @override
  String get importData => '匯入資料';

  @override
  String get exportSuccess => '資料匯出成功';

  @override
  String get importSuccess => '資料匯入成功';

  @override
  String get importFailed => '匯入失敗';

  @override
  String get importConfirm => '這將覆蓋目前資料，確定繼續？';

  @override
  String get settingsStorageLocation => '儲存位置';

  @override
  String get settingsStoragePathHint => '輸入自訂資料儲存目錄路徑，留空使用預設位置。';

  @override
  String get settingsDirectoryPath => '目錄路徑';

  @override
  String get settingsResetDefault => '恢復預設';

  @override
  String get settingsResetDefaultLocation => '儲存位置已恢復預設';

  @override
  String get settingsStoragePathUpdated => '儲存位置已更新';

  @override
  String get dataMigration => '開啟資料目錄';

  @override
  String get dataMigrationDesc => '開啟應用程式資料夾';

  @override
  String get homeCalendarJst => '日曆日期為 JST（日本標準時間 UTC+9）';

  @override
  String get animeShare => '分享';

  @override
  String get shareCopied => '圖片已複製到剪貼簿';

  @override
  String get shareCopy => '複製';

  @override
  String get shareSaveAs => '另存為';

  @override
  String get shareSaveAll => '全部儲存';

  @override
  String sharePagesLabel(int count) {
    return '$count 頁';
  }

  @override
  String get shareSaved => '圖片已儲存';

  @override
  String get shareFailed => '分享失敗';

  @override
  String get shareUrlOptions => '包含連結';

  @override
  String get statsTitle => '統計';

  @override
  String get statsQuarter => '季度';

  @override
  String get statsYear => '年度';

  @override
  String get statsAll => '全部';

  @override
  String get statsTracked => '追番';

  @override
  String get statsCompleted => '看完';

  @override
  String get statsDropped => '放棄';

  @override
  String get statsWatching => '在追';

  @override
  String get statsNotStarted => '未開始';

  @override
  String get statsTrend => '趨勢';

  @override
  String get statsRanking => '排行';

  @override
  String get statsRankingFilters => '篩選';

  @override
  String get statsRankingTimeFilter => '時間';

  @override
  String get statsRankingTypeFilter => '類型';

  @override
  String get statsRankingAllTypes => '全部類型';

  @override
  String get statsRankingSortBy => '排序依據';

  @override
  String get statsRankingScoreSource => '評分來源';

  @override
  String get statsRankingScoreSourcePersonal => '我的評分';

  @override
  String get statsRankingScoreSourceExternal => '資料庫';

  @override
  String get statsRankingExternalSource => '資料庫來源';

  @override
  String get statsRankingExternalAverage => '所有來源平均';

  @override
  String get statsRankingDescending => '從高到低';

  @override
  String get statsRankingAscending => '從低到高';

  @override
  String get statsRankingDescShort => '降序';

  @override
  String get statsRankingAscShort => '升序';

  @override
  String get statsRankingCustomRange => '自訂範圍';

  @override
  String get statsRankingSelectYear => '選擇年度';

  @override
  String get statsRankingStartQuarter => '開始季度';

  @override
  String get statsRankingEndQuarter => '結束季度';

  @override
  String get statsRankingEmpty => '沒有符合篩選條件的已評分番劇';

  @override
  String statsRankingCount(int count) {
    return '$count 部已評分番劇';
  }

  @override
  String get manageJumpToQuarter => '跳轉到季度';

  @override
  String get manageNoSearchResults => '沒有匹配的番劇';

  @override
  String get manageFilterArchive => '本機存檔';

  @override
  String get manageFilterAll => '全部';

  @override
  String get manageFilterArchived => '已存檔';

  @override
  String get manageFilterNotArchived => '未存檔';

  @override
  String get manageOther => '其他';

  @override
  String get dayMon => '週一';

  @override
  String get dayTue => '週二';

  @override
  String get dayWed => '週三';

  @override
  String get dayThu => '週四';

  @override
  String get dayFri => '週五';

  @override
  String get daySat => '週六';

  @override
  String get daySun => '週日';

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
    return '今日放送 $animeCount 部番劇，$episodeCount 話';
  }

  @override
  String reminderUnwatched(int animeCount, int episodeCount) {
    return '待看 $animeCount 部番劇，$episodeCount 話';
  }

  @override
  String syncConflictTitle(String name) {
    return '同步衝突: $name';
  }

  @override
  String get syncConflictDesc => '此番劇在上次同步後在兩台裝置上均被修改。';

  @override
  String get syncLocalVersion => '本地版本:';

  @override
  String get syncRemoteVersion => '遠端版本:';

  @override
  String syncModifiedAt(String time) {
    return '修改時間: $time';
  }

  @override
  String syncEpisodeRange(int start, int end) {
    return '集數: $start〜$end';
  }

  @override
  String syncWatched(int count) {
    return '已觀看: $count';
  }

  @override
  String get syncKeepLocal => '保留本地';

  @override
  String get syncKeepRemote => '保留遠端';

  @override
  String searchEpisodesCount(int count) {
    return '$count話';
  }

  @override
  String get animeSeasonHint => '第1季';

  @override
  String get shareTypeTitle => '分享方式';

  @override
  String get shareAsImage => '分享為圖片';

  @override
  String get shareAsData => '分享為資料檔案';

  @override
  String get shareAsTxt => '匯出為 TXT（僅名稱）';

  @override
  String get statsShareTxtEmpty => '沒有可匯出的番劇';

  @override
  String get importAnimeSuccess => '番劇匯入成功';

  @override
  String get importAnimeFailed => '匯入失敗';

  @override
  String get statsShare => '分享統計';

  @override
  String statsShareSummary(String scope, int count) {
    return '$scope · $count 部番劇';
  }

  @override
  String get importBundleTitle => '匯入番劇';

  @override
  String importBundleCount(int count) {
    return '檔案中找到 $count 部番劇';
  }

  @override
  String importBundleConflictTitle(String name) {
    return '匯入衝突: $name';
  }

  @override
  String get importBundleConflictDesc => '這部番劇已存在於你的資料庫中。';

  @override
  String get importBundleLocalVersion => '本地版本:';

  @override
  String get importBundleImportedVersion => '匯入版本:';

  @override
  String get importBundleKeepLocal => '保留本地';

  @override
  String get importBundleKeepImport => '使用匯入';

  @override
  String get importBundleMerge => '合併';

  @override
  String importBundleSuccess(int count) {
    return '成功匯入 $count 部番劇';
  }

  @override
  String get importBundleNoConflicts => '未發現衝突，正在匯入全部…';

  @override
  String get settingsDuplicateCheck => '檢查重複';

  @override
  String get settingsDuplicateCheckDesc => '尋找並合併重複的番劇記錄';

  @override
  String get duplicateCheckTitle => '重複檢查';

  @override
  String get duplicateCheckEmpty => '未發現重複';

  @override
  String duplicateCheckFound(int count) {
    return '發現 $count 組重複';
  }

  @override
  String get duplicateReasonSameId => '相同 ID';

  @override
  String get duplicateReasonSameUrl => '相同連結';

  @override
  String get duplicateReasonSameTitleSeason => '相同標題/季度';

  @override
  String duplicateGroupLabel(int index, int total, String reason) {
    return '第 $index/$total 組: $reason';
  }

  @override
  String get duplicateKeepFirst => '保留此項';

  @override
  String get duplicateMergeAll => '全部合併到此';

  @override
  String get duplicateDeleteOthers => '刪除其他項';

  @override
  String get duplicateResolved => '重複已成功解決';

  @override
  String get duplicateResolveConfirm => '解決此重複組？';

  @override
  String get addAnimeCreate => '新建番劇';

  @override
  String get addAnimeImport => '從檔案匯入';

  @override
  String get exportAsZip => '匯出為 ZIP';

  @override
  String get exportAsZipDesc => '完整資料壓縮包（番劇資料 + 封面圖片），用於備份或遷移';

  @override
  String get exportAsMarkdown => '匯出為 Markdown';

  @override
  String get exportAsMarkdownDesc => '按開播時間排列的番劇列表及觀看狀態，用於 LLM 個人化學習';

  @override
  String get trayShow => '顯示';

  @override
  String get trayQuit => '退出';

  @override
  String get settingsMinimizeToTray => '最小化到系統匣';

  @override
  String get settingsCloseToTray => '關閉到系統匣';

  @override
  String get settingsAutoStart => '開機自啟';

  @override
  String get settingsApiServer => 'API 伺服器設定';

  @override
  String get settingsApiEnabled => '本機 API 伺服器';

  @override
  String get settingsApiListenAddress => '監聽位址';

  @override
  String get settingsApiPort => '連接埠';

  @override
  String get settingsApiUsername => '使用者名稱';

  @override
  String get settingsApiPassword => '密碼';

  @override
  String settingsApiRunning(int port) {
    return '運行中，連接埠 $port';
  }

  @override
  String get settingsApiStopped => '已停止';

  @override
  String get settingsApiNeedCredentials => '監聽非 localhost 時需設定使用者名稱和密碼';

  @override
  String get settingsApiRestart => '重啟伺服器';

  @override
  String settingsApiRestarted(int port) {
    return 'API 伺服器已在連接埠 $port 重啟';
  }

  @override
  String get kanaTitle => '五十音速查';

  @override
  String get kanaScriptHiragana => '平假名';

  @override
  String get kanaScriptKatakana => '片假名';

  @override
  String get kanaSearchHint => '搜尋假名或羅馬音…';

  @override
  String kanaSearchResults(int count) {
    return '符合 ($count)';
  }

  @override
  String get kanaNoMatches => '沒有符合的假名';

  @override
  String get kanaBasicSection => '清音五十音';

  @override
  String get kanaVoicedSection => '濁音 / 半濁音';

  @override
  String get kanaYoonSection => '拗音';

  @override
  String get kanaRulesSection => '發音規則';

  @override
  String get kanaRuleMoraTitle => '一個假名一拍';

  @override
  String get kanaRuleMoraBody => '每個假名佔一個 mora。像 ka-ki-ku-ke-ko 一樣保持均勻節奏。';

  @override
  String get kanaRuleVowelsTitle => '母音穩定';

  @override
  String get kanaRuleVowelsBody => 'a, i, u, e, o 要短而清楚，不像英語弱讀母音那樣被吞掉。';

  @override
  String get kanaRuleDakutenTitle => '濁音與半濁音';

  @override
  String get kanaRuleDakutenBody => '゛讓子音濁化: k 變 g，s 變 z，t 變 d，h 變 b。゜讓 h 變 p。';

  @override
  String get kanaRuleYoonTitle => '拗音組合';

  @override
  String get kanaRuleYoonBody => '小寫 ゃ/ゅ/ょ 與 i 段假名合併: き + ゃ = きゃ kya。';

  @override
  String get kanaRuleSokuonTitle => '促音';

  @override
  String get kanaRuleSokuonBody => '小寫 っ/ッ 表示下一個子音前有短暫停頓，並雙寫子音，如 まって matte。';

  @override
  String get kanaRuleLongVowelsTitle => '長音';

  @override
  String get kanaRuleLongVowelsBody => 'ー 延長片假名音。平假名裡 おう 常讀長 o，えい 常讀長 e。';

  @override
  String get kanaRuleNTitle => 'ん / ン';

  @override
  String get kanaRuleNBody => '通常讀 n；在 m, b, p 前接近 m，在 k, g 前會變成較輕的鼻音。';

  @override
  String get statsShareStatusTitle => '包含的狀態';

  @override
  String get statsShareStatusHint => '選擇要包含的觀看狀態';

  @override
  String get statsShareLimitTitle => '大量圖片分享';

  @override
  String statsShareLimitWarning(int count) {
    return '共 $count 部，產生可能耗時較長。';
  }

  @override
  String get statsShareLimitEnable => '設定條目上限';

  @override
  String get statsShareLimitCount => '上限';

  @override
  String get statsShareLimitPriority => '優先順序';

  @override
  String get statsSharePriorityRecent => '時間近（首播日）';

  @override
  String get statsSharePriorityOldest => '時間遠（首播日）';

  @override
  String get statsShareGenerating => '正在產生圖片，可能耗時較長…';

  @override
  String statsShareGeneratingProgress(int done, int total) {
    return '載入封面: $done/$total';
  }

  @override
  String statsShareTruncated(int shown, int total) {
    return '$shown/$total 部（已截斷）';
  }

  @override
  String get settingsDesktop => '桌面';
}
