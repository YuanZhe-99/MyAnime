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
  String get navSettings => '设置';

  @override
  String homeAiringOn(String date) {
    return '$date 播出';
  }

  @override
  String homeUnwatched(int count) {
    return '未看 ($count)';
  }

  @override
  String get homeEmpty => '还没有番剧，添加一部开始追番吧！';

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
  String get searchAnimeInfo => '搜索番剧信息';

  @override
  String get searchHint => '输入标题搜索…';

  @override
  String get searchButton => '搜索';

  @override
  String get searchNoResults => '未找到结果';

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
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTest => '测试';

  @override
  String get settingsWebDAVAutoSync => '自动同步';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

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
  String get backupRestore => '恢复';

  @override
  String get backupRestoreConfirm => '这将覆盖当前数据，确定继续？';

  @override
  String get backupRestored => '备份已恢复';

  @override
  String get backupRestoreFailed => '恢复失败';

  @override
  String get backupDeleteConfirm => '删除此备份？';

  @override
  String get backupRestoreModules => '选择要恢复的数据';

  @override
  String get backupSelectAll => '全选';

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
  String get manageJumpToQuarter => '跳转到季度';

  @override
  String get manageNoSearchResults => '没有匹配的番剧';

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
  String get reminderNotifBody => '查看你的动漫日程！';

  @override
  String reminderAiringToday(int count) {
    return '今日放送: $count话';
  }

  @override
  String reminderUnwatched(int count) {
    return '未观看: $count话';
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
  String get importAnimeSuccess => '番剧导入成功';

  @override
  String get importAnimeFailed => '导入失败';
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
  String get navSettings => '設定';

  @override
  String homeAiringOn(String date) {
    return '$date 播出';
  }

  @override
  String homeUnwatched(int count) {
    return '未看 ($count)';
  }

  @override
  String get homeEmpty => '還沒有番劇，新增一部開始追番吧！';

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
  String get searchAnimeInfo => '搜尋番劇資訊';

  @override
  String get searchHint => '輸入標題搜尋…';

  @override
  String get searchButton => '搜尋';

  @override
  String get searchNoResults => '未找到結果';

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
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTest => '測試';

  @override
  String get settingsWebDAVAutoSync => '自動同步';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

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
  String get backupRestoreConfirm => '這將覆蓋目前資料，確定繼續？';

  @override
  String get backupRestored => '備份已還原';

  @override
  String get backupRestoreFailed => '還原失敗';

  @override
  String get backupDeleteConfirm => '刪除此備份？';

  @override
  String get backupRestoreModules => '選擇要還原的資料';

  @override
  String get backupSelectAll => '全選';

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
  String get manageJumpToQuarter => '跳轉到季度';

  @override
  String get manageNoSearchResults => '沒有匹配的番劇';

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
  String get reminderNotifBody => '查看你的動漫日程！';

  @override
  String reminderAiringToday(int count) {
    return '今日放送: $count話';
  }

  @override
  String reminderUnwatched(int count) {
    return '未觀看: $count話';
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
  String get importAnimeSuccess => '番劇匯入成功';

  @override
  String get importAnimeFailed => '匯入失敗';
}
