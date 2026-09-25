# English → Simplified Chinese Translation Guide

This guide governs how `doc/zh-cn/` is produced and kept in sync with `doc/en-us/` across
MyAnime, MyDay, MyDevice, and MyApps-DATA. Sections 1-4 and 6 are copied byte-identically into
every repo's `doc/en-us/translation-guide.md`; Section 5's glossary is split into a shared core
that is identical everywhere plus a per-repo section for terms only that repo uses (and, once the
Chinese tree exists, `doc/zh-cn/translation-guide.md` holds the Chinese rendering of this same
guide). Read this before writing or updating any Chinese documentation page.

## 1. Scope and workflow

- `doc/en-us/` is authoritative. `doc/zh-cn/` is a translation of it, never an independent source.
- English content is authored first, directly from the actual source code and `AGENTS.md`.
  Chinese content is then produced from the finished English page using this guide and the
  glossary in Section 5.
- Any future change to a function, data format, sync rule, or feature must update the English
  page and the Chinese page in the same commit. Do not let the two trees drift.
- New terminology encountered while translating goes into Section 5. Put it in **Section 5.1** and
  copy it to all four repos only if the term is genuinely cross-cutting (sync, backup, storage,
  documentation, Flutter and Dart vocabulary). If it names something only one app has, put it in
  that repo's **Section 5.2** and leave the other repos alone — a term nobody in MyDevice can
  encounter does not belong in MyDevice's glossary.

## 2. Structural parity rules

`doc/zh-cn/<path>` must mirror `doc/en-us/<path>` exactly:

- The same set of files exists in both trees — no file present in one language and missing in
  the other.
- The same heading hierarchy and count (`#`, `##`, `###`, ...).
- The same number of tables and table rows, in the same order.
- The same number of fenced code blocks, with **identical code inside** (code is data, not prose).
- The same internal links and anchors, pointing at the translated equivalents.

A verification pass compares heading counts, table-row counts, and code-fence counts between the
two trees file-by-file; both must match exactly.

## 3. What is never translated

- Identifiers: class/function/variable/field names, file paths, directory names.
- CLI commands and their flags/output.
- Configuration keys (e.g. `storage_config.json` keys, `webdav_config.json` keys).
- URLs and the masked placeholder `<local_gitea_address>`.
- Product, framework, and protocol names: WebDAV, Riverpod, go_router, Flutter, Dart, Gitea,
  GitHub, MSIX, Inno Setup, AGP, Gradle, Jikan, AniList.
- The Tier A / Tier B labels used in the function index.
- Anything inside a fenced code block, including comments written as part of example code,
  unless the comment is prose explaining the example outside the executable line — in which case
  translate the explanatory comment text but never the code tokens themselves.

## 4. Style rules

- Use a neutral, declarative technical tone. Do not use the formal pronoun 您; use 你 only if a
  second-person address is unavoidable, otherwise prefer impersonal phrasing.
- Use full-width Chinese punctuation in prose (，。：；「」) but keep all Markdown syntax
  characters (`#`, `` ` ``, `|`, `-`, `*`, `[]()`) in their normal ASCII form so Markdown still
  parses.
- Insert a single space between CJK characters and adjacent Latin letters or digits
  (e.g. "支持 WebDAV 同步", "保留 60 秒").
- Keep sentences short; prefer splitting a long English sentence into two Chinese sentences over
  producing one dense run-on sentence.
- Numbers, version numbers, file names, and code identifiers stay exactly as written in English.

## 5. Terminology glossary

Section 5.1 is the shared core and must stay identical in all four repos. Section 5.2 lists terms
specific to this repo's own domain and deliberately differs per repo. Before adding a term, decide
which one it belongs in — see the rule in Section 1.

### 5.1 Shared core (identical in all four repos)

| English | 中文 | Notes |
|---|---|---|
| sync / synchronization | 同步 | |
| three-way merge | 三方合并 | base/local/remote 三方 |
| base snapshot | 基线快照 | the `.sync_base` copy used for merge comparison |
| conflict / conflict resolution | 冲突 / 冲突解决 | |
| auto-resolve | 自动解决 | |
| backup / restore | 备份 / 恢复 | |
| snapshot | 快照 | |
| blob | blob | 不译；指内容寻址的二进制附件对象 |
| retention (policy) | 保留策略 | |
| WebDAV | WebDAV | 不译 |
| lock / lock file | 锁 / 锁文件 | |
| heartbeat | 心跳 | periodic lock-refresh signal |
| stale lock | 过期锁 | |
| interrupted upload | 中断的上传 | |
| provider | provider | Riverpod 术语，不译 |
| route / router | 路由 / 路由器 | |
| deep link | 深层链接 | |
| flavor (build flavor) | 构建风味 | Flutter build flavor 概念，不译作"口味"以外的怪异译法时保留英文首次标注 |
| barrel file | 桶文件（barrel file） | 首次出现附英文原词 |
| unknown-key preservation | 未知键保留 | 向前兼容的数据保留机制 |
| duplicate detection | 重复检测 | |
| declaration | 声明 | function/method/constructor/getter/setter 统称 |
| getter / setter | getter / setter | 不译 |
| widget | 组件（widget） | 首次出现附英文原词 |
| side effects | 副作用 | |
| remote (git) | 远程仓库 | |
| submodule | 子模块 | git submodule |
| facade | 门面（facade） | 设计模式术语，首次出现附英文原词 |
| atomic write | 原子写入 | tmp-then-rename pattern |
| storage hub | 存储中枢 | per-app central storage class |
| function index | 函数索引 | |
| algorithm documentation | 算法文档 | |
| usage / example documentation | 用法 / 示例文档 | |
| Tier A / Tier B | Tier A / Tier B | 文档覆盖分级标签，不译 |
| build method | build 方法 | Flutter widget 的 build() |
| l10n / localization | 本地化（l10n） | |
| ARB file | ARB 文件 | Application Resource Bundle |
| ZIP export / import | ZIP 导出 / 导入 | |
| path traversal | 路径穿越 | 安全术语，指目录遍历攻击 |
| allowlist | 允许列表 | |
| garbage collection (GC) | 垃圾回收（GC） | 指备份 blob 的引用计数回收 |
| debounce | 防抖 | |
| wake lock | 唤醒锁 | screen wake lock, `wakelock_plus` |
| adaptive layout | 自适应布局 | |
| window size class | 窗口尺寸类别 | Material 的 compact/medium/expanded 分级 |
| breakpoint | 断点 | 布局阈值 |
| viewport | 视口 | |
| logical pixel (dp) | 逻辑像素（dp） | 与密度无关的布局单位 |
| aspect ratio | 宽高比 | width / height |
| foldable | 折叠屏设备 | |
| cover screen | 外屏 | 折叠状态下的外部屏幕 |
| split layout | 分栏布局 | |
| pane | 窗格（pane） | 首次出现附英文原词 |
| two-pane | 双栏 | 左右两个窗格的布局 |
| navigation rail | 导航栏（NavigationRail） | Material 侧边导航；不译作「轨道」 |
| bottom navigation bar | 底部导航栏 | |
| content width | 内容宽度 | 扣除导航栏后页面内容实际获得的宽度 |
| column capacity | 列容量 | 给定最小列宽时一行能容纳的列数 |

### 5.2 MyAnime-specific terms

Not copied to the other repos — no other app has these.

| English | 中文 | Notes |
|---|---|---|
| tray (system tray) | 系统托盘 | |
| local API server | 本地 API 服务器 | |
| trend chart | 趋势图 | |
| metric | 指标 | a selectable series on a trend chart |
| quarter / cour | 季度 / 一季（cour） | 动画播出档期语境下保留英文 cour |
| episode | 集 | |
| air date / air time | 播出日期 / 播出时间 | |
| JST (Japan Standard Time) | 日本标准时间（JST） | 番组播出时间基准时区 |
| local archive | 本地存档 | 是否下载并保管了本地资源的记录；zh-TW 用「本機存檔」，ja 用「ローカル保存」 |
| archive source | 片源 | BD/DVD/WEB/TV 等来源介质；BD、DVD、WEB、TV 本身不翻译 |
| resolution | 分辨率 | zh-TW 用「解析度」；2160p/1080p/720p/480p 本身不翻译 |
| archive copies | 存档份数 | 保存了几份拷贝 |
| repository / location | 资料仓库代码或位置 | 存放本地资源的仓库代码或物理位置，自由文本 |
| external metadata / database info | 外部元数据 / 资料库信息 | 从外部番剧资料库拉取的公开信息；zh-TW 用「資料庫資訊」，ja 用「データベース情報」 |
| external rating | 外部评分 | 外部资料库的评分，与用户自己的「评分」严格区分，绝不混写 |
| alternate title / synonym | 别名 | 各语言的其他标题；zh-TW 用「別名」，ja 用「別名」 |
| romaji title | 罗马音标题 | `titleRomaji`；罗马音本身不翻译 |
| studio | 制作公司 | zh-TW 用「製作公司」，ja 用「制作会社」 |
| genre | 类型标签 | 作品的题材标签，不要译成「流派」 |
| broadcast schedule | 放送排期 | 来自数据源的实际放送时段表 |
| two-round / cross-language search | 两阶段跨语言检索 | 先按源定向、再用命中标题补搜零结果来源 |
| backfill | 补搜 | 第二轮针对零结果来源的补充查询 |
| relevance | 相关度 | 结果与查询的模糊匹配得分，用作默认排序 |
| refresh (metadata) | 刷新（资料库信息） | 按已保存的来源 URL 回源重新抓取；zh-TW 用「重新整理」 |
| background update | 后台更新 | 应用打开时自动进行的资料刷新与探索；zh-TW 用「背景更新」，ja 用「バックグラウンド更新」 |
| split (layout) | 分栏 | 布局拆成左右两栏或多列；不要译成「分割」 |
| column count | 列数 | 列表的多列列数；zh-TW 用「欄數」 |
| navigation rail | 侧边导航栏 | 宽屏下取代底部导航栏的竖向导航；zh-TW 用「側邊導覽列」 |
| navigation bar | 底部导航栏 | 窄屏下的横向导航；与侧边导航栏成对出现，勿混用 |
| list-detail | 列表-详情 | 左边一级列表、右边二级页面的布局；勿译成「主从」 |
| detail pane | 详情栏 | 列表-详情布局的右栏；「栏」用于左右分栏，「列」用于多列列表 |
| window size class | 窗口尺寸等级 | Material 的 compact/medium/expanded 断点分级 |
| foldable | 折叠屏 | zh-TW 用「摺疊螢幕」，ja 用「折りたたみ」 |
| aspect ratio | 宽高比 | 拆分判据中的宽除以高 |
| series index | 系列索引 | anime1.me 的 `animelist.json`，站点全部作品的一张表 |
| watch URL | 观看链接 | zh-TW 用「觀看連結」，ja 用「視聴URL」 |
| folded form / fold | 归一化形式 / 归一化 | 只用于匹配、不用于显示的标题形式：半角、小写、去标点、转简体 |
| season boost | 档期加分 | 行的年份/季节与记录首播季度一致时的加分 |
| alias harvest | 别名补采 | 本地无命中时向 bangumi.tv 取一次别名再匹配 |
| episode text | 集数文本 | anime1 的原文单元格，如 `1-12+OVA`、`連載中(09)` |
| watch progress | 观看进度 | 观看站点已更新到第几集；zh-TW 用「觀看進度」，ja 用「視聴進捗」 |
| update proposal | 更新建议 | 已下载但等待用户确认的核心字段改动，绝不自动应用 |
| discovery | 探索 | 为资料不全的记录发起的全源搜索，区别于「刷新」 |
| confidence threshold | 置信度阈值 | 决定一条搜索结果是否值得提议的相关度下限 |
| needs manual selection | 需要手动选择 | 匹配不够可靠、被排除在批量更新之外的条目 |
| backoff | 退避 | 连续失败后逐级拉长的重试间隔 |
| cover prefetch | 封面预下载 | 提前下载候选封面到本地缓存，默认关闭 |
| series | 系列 | 一部作品的各季、剧场版与 OVA 组成的有序分组；与 anime1.me 的「系列索引」（series index）无关，勿混用 |
| curated series | 手动关联的系列 | 用户操作创建、共享同一 `seriesId` 的系列；成员完全按用户所设 |
| derived series | 自动归入的系列 | 应用根据标题或关联关系算出的系列，不写入任何数据；界面文案为「自动归入」 |
| series grouping (`SeriesIndex`) | 系列分组 | 1.6.0 起在内存中计算全部系列的结构；虽然类名叫 `SeriesIndex`，中文勿译成「系列索引」，那是 anime1.me 的片库表 |
| standalone | 独立（不归入系列） | 用户把记录移出所有系列（`standalone: true`）；它不加入任何系列，也不吸引其他记录 |
| next season | 下一季 | 「添加下一季」操作，预填标题与递增后的季标签 |
| materialise (a series) | 固化（系列） | 首次手动整理时给自动归入的系列的每个成员写入同一 `seriesId` |
| relation (database) / related work | 关联关系 / 关联作品 | `externalMeta.relations`：资料库列出的前作、续作等；与用户的「手动关联」（series link）不同，勿混写 |
| spin-off | 衍生作品 | `spinOff`；共享世界观但不同系列，只作建议 |
| alternative version | 不同版本 | `alternative`；只作建议 |
| missing sequel | 缺失续作 | 资料库列出、但片库中没有的续作；界面文案为「下一部：<标题>（<来源>）」 |
| canonical (database) key | 规范键 | `anilist:<id>` / `mal:<id>` / `bgm:<id>`，用于把关联目标与记录的页面匹配 |
| on-device AI | 端侧 AI | 在本设备上运行的模型；与 MyNihongo 一致。勿译成「本地 AI」或「设备端 AI」 |
| Apple Intelligence / AICore / Foundation Models | Apple Intelligence / AICore / Foundation Models | 平台与框架名，不翻译 |
| category | 分类 | 本应用自己的分类表（`animeCategories`）中的一项；与资料库的「类型标签」（genre）不同，勿混用 |
| automatic categories | 自动分类 | 由类型标签映射、必要时由端侧 AI 补全得出的分类；用户自己选的分类始终优先 |
| recommendation | 推荐 | 从用户自己的片库中挑出接下来看什么；界面标题为「接下来看什么」。模型只按编号挑选，从不自己说出作品名 |
| reason chip | 推荐理由标签 | 推荐卡片上说明理由的小标签，如「《…》的下一部」 |
| Not interested | 不感兴趣 | 把一条推荐移入垃圾箱；1.6.0–1.6.1 只在本设备上隐藏、不同步，自 1.6.2 起同步并可恢复 |
| recommendation trash | 推荐垃圾箱 | 1.6.2 起：放「不感兴趣」和刷新时略过的推荐，可同步、可恢复；分全局垃圾箱与每部作品自己的垃圾箱。zh-TW 用「垃圾桶」，ja 用「ゴミ箱」 |
| restore (from the trash) | 恢复 | 从垃圾箱中移出，使其可以再次被推荐；zh-TW 用「還原」，ja 用「戻す」 |
| refresh (recommendations) | 换一批 | 把当前显示的一批移入垃圾箱，再显示下一批；与资料库信息的「刷新」不同，勿混用 |
| related recommendations | 相关推荐 | 详情页上与该作品相似的片库内作品，持久保存直到刷新；ja 用「関連作品」 |
| pin (a recommendation) | 钉选 | 1.6.3 起：让一张推荐卡片在「换一批」时保留并排在最前；取消为「取消钉选」。zh-TW 用「釘選」，ja 用「ピン留め」。勿译成「置顶」（那暗示排序而非保留）或「收藏」 |
| sequel info | 续作资料 | 1.6.3 起：缺失续作卡片上从资料库取得的简介与封面缩略图，同步保存，移入垃圾箱时删除 |
| thumbnail | 缩略图 | 缩小后的封面，内嵌在 `recommendations.json` 中；zh-TW 用「縮圖」，ja 用「サムネイル」 |
| info line / action row (detail page) | 信息行 / 操作行 | 1.6.3 起详情页标题下方的两行：一行纯文字的季标签·长度·星期·时间，一行按钮 |
| series view (Manage) | 按系列查看 | 管理页的另一种布局：每个系列一行、可展开成员；与「按季度查看」相对 |
| season label | 季标签 | `Anime.season` 的自由文本，如 `Season 2`、`第二季`；勿写成「季度标签」，「季度」专指播出档期（quarter） |
| default season label | 默认季标签 | `Season 1` 或空；自 1.6.1 起只有它会按标题自动改写为 `Season N` |
| split-cour marker | 分割放送标记 | 标题中的 `Part 2`、`Cour 2`、`第2クール`；表示同一季的后半部分，不是新的一季 |
| partial results | 部分结果 | 检索仍在进行时已经到达的结果；自 1.6.1 起即时显示 |

## 6. Review checklist (run before committing a Chinese page)

- [ ] File exists at the same relative path under `doc/zh-cn/` as its English counterpart.
- [ ] Heading count matches (`grep -c '^#'`).
- [ ] Code-fence count matches (`grep -c '^```'`), and code contents are byte-identical to English.
- [ ] Table row counts match.
- [ ] Every glossary term used matches Section 5 exactly; any new cross-cutting term was added to
      Section 5.1 in all four repos, and any app-specific term was added only to this repo's
      Section 5.2.
- [ ] No real Gitea host appears; `<local_gitea_address>` is used wherever the host would be.
- [ ] Internal links resolve to the Chinese-tree equivalents, not back to `doc/en-us/`.
