# 英译中翻译指南

本指南规定 `doc/zh-cn/` 如何在 MyAnime、MyDay、MyDevice 和 MyApps-DATA 四个仓库中生成并与 `doc/en-us/` 保持同步。第 1–4 节和第 6 节被逐字节复制到每个仓库的 `doc/en-us/translation-guide.md`；第 5 节的术语表被拆分为四处完全相同的共享核心，外加每个仓库只归自己用的术语一节（并且，一旦中文树存在，`doc/zh-cn/translation-guide.md` 就保存这份指南的中文版）。在编写或更新任何中文文档页面之前先读本指南。

## 1. 范围与工作流

- `doc/en-us/` 是权威。`doc/zh-cn/` 是它的翻译，绝不是独立的来源。
- 英文内容优先编写，直接依据实际源代码和 `AGENTS.md`。然后使用本指南和第 5 节的术语表，从完成后的英文页面产出中文内容。
- 任何未来对函数、数据格式、同步规则或功能的变更，必须在同一提交中同时更新英文页面和中文页面。绝不让两棵树漂移。
- 翻译中遇到的新术语写进第 5 节。只有当该术语确实跨领域（同步、备份、存储、文档、Flutter 和 Dart 词汇）时，才放进 **5.1 节**并复制到全部四个仓库。如果它只指某个应用独有的东西，放进该仓库的 **5.2 节**，不要动其他仓库——MyDevice 里没人能遇到的术语不属于 MyDevice 的术语表。

## 2. 结构对等规则

`doc/zh-cn/<path>` 必须与 `doc/en-us/<path>` 完全镜像：

- 两棵树中存在同一组文件——任何文件不得只存在于一种语言而缺失于另一种。
- 相同的标题层级和数量（`#`、`##`、`###`、……）。
- 相同数量的表格和表格行，顺序相同。
- 相同数量的围栏代码块，**代码内部逐字节相同**（代码是数据，不是散文）。
- 相同的内部链接和锚点，指向翻译后的对应物。

验证过程会逐文件比较两棵树的标题数、表格行数和代码围栏数；两者必须完全一致。

## 3. 绝不翻译的内容

- 标识符：类/函数/变量/字段名、文件路径、目录名。
- CLI 命令及其标志/输出。
- 配置键（如 `storage_config.json` 的键、`webdav_config.json` 的键）。
- URL 和被掩码的占位符 `<local_gitea_address>`。
- 产品、框架和协议名称：WebDAV、Riverpod、go_router、Flutter、Dart、Gitea、GitHub、MSIX、Inno Setup、AGP、Gradle、Jikan、AniList。
- 函数索引中使用的 Tier A / Tier B 标签。
- 围栏代码块内的任何内容，包括作为示例代码一部分写下的注释——除非该注释是在可执行行之外解释示例的散文，此时只翻译解释性注释文字，绝不翻译代码记号本身。

## 4. 风格规则

- 使用中性、陈述性的技术语气。不要使用敬称"您"；只有在无法避免第二人称时才用"你"，否则优先使用无人称表达。
- 散文中使用全角中文标点（，。：；「」），但所有 Markdown 语法字符（`#`、`` ` ``、`|`、`-`、`*`、`[]()`）保持正常 ASCII 形式，使 Markdown 仍能解析。
- 在 CJK 字符与相邻的拉丁字母或数字之间插入一个空格（如"支持 WebDAV 同步"、"保留 60 秒"）。
- 保持句子简短；宁可把一句长英文拆成两句中文，也不要写出一句冗长缠绕的长句。
- 数字、版本号、文件名和代码标识符与英文中完全一致。

## 5. 术语表

5.1 节是共享核心，四个仓库必须保持一致。5.2 节列出本仓库自身领域特有的术语，每个仓库刻意不同。添加术语前，先判断它属于哪一节——见第 1 节的规则。

### 5.1 共享核心（四个仓库完全相同）

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

### 5.2 MyAnime 特有术语

不复制到其他仓库——没有其他应用拥有这些。

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

## 6. 复查清单（提交中文页面之前运行）

- [ ] 文件存在于 `doc/zh-cn/` 下与其英文对应物相同的相对路径。
- [ ] 标题数量一致（`grep -c '^#'`）。
- [ ] 代码围栏数量一致（`grep -c '^```'`），且代码内容与英文逐字节相同。
- [ ] 表格行数一致。
- [ ] 用到的每个术语表条目都与第 5 节完全一致；任何新增的跨领域术语已添加到全部四个仓库的 5.1 节，任何应用特有术语只添加到本仓库的 5.2 节。
- [ ] 不出现真实 Gitea 主机；凡是需要主机的地方都用 `<local_gitea_address>`。
- [ ] 内部链接指向中文树的对应物，而不是指回 `doc/en-us/`。
