# English → Simplified Chinese Translation Guide

This guide governs how `doc/zh-cn/` is produced and kept in sync with `doc/en-us/` across
MyAnime, MyDay, MyDevice, and MyApps-DATA. It is copied byte-identically into every repo's
`doc/en-us/translation-guide.md` (and, once the Chinese tree exists, `doc/zh-cn/translation-guide.md`
holds the Chinese rendering of this same guide). Read this before writing or updating any
Chinese documentation page.

## 1. Scope and workflow

- `doc/en-us/` is authoritative. `doc/zh-cn/` is a translation of it, never an independent source.
- English content is authored first, directly from the actual source code and `AGENTS.md`.
  Chinese content is then produced from the finished English page using this guide and the
  glossary in Section 5.
- Any future change to a function, data format, sync rule, or feature must update the English
  page and the Chinese page in the same commit. Do not let the two trees drift.
- New terminology encountered while translating must be added to Section 5 in **all four repos**,
  not just the one being worked on.

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

New entries must be appended here and copied into all four repos' copies of this file.

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
| quarter / cour | 季度 / 一季（cour） | 动画播出档期语境下保留英文 cour |
| episode | 集 | |
| air date / air time | 播出日期 / 播出时间 | |
| tray (system tray) | 系统托盘 | |
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
| local API server | 本地 API 服务器 | |
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
| JST (Japan Standard Time) | 日本标准时间（JST） | |
| ZIP export / import | ZIP 导出 / 导入 | |
| path traversal | 路径穿越 | 安全术语，指目录遍历攻击 |
| allowlist | 允许列表 | |
| garbage collection (GC) | 垃圾回收（GC） | 指备份 blob 的引用计数回收 |
| debounce | 防抖 | |
| wake lock | 唤醒锁 | screen wake lock, `wakelock_plus` |

## 6. Review checklist (run before committing a Chinese page)

- [ ] File exists at the same relative path under `doc/zh-cn/` as its English counterpart.
- [ ] Heading count matches (`grep -c '^#'`).
- [ ] Code-fence count matches (`grep -c '^```'`), and code contents are byte-identical to English.
- [ ] Table row counts match.
- [ ] Every glossary term used matches Section 5 exactly; any new term was added to Section 5 in
      all four repos.
- [ ] No real Gitea host appears; `<local_gitea_address>` is used wherever the host would be.
- [ ] Internal links resolve to the Chinese-tree equivalents, not back to `doc/en-us/`.
