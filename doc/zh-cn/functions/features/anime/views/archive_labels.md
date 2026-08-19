# lib/features/anime/views/archive_labels.dart

三个纯标签辅助函数，把 [`../models/anime.md`](../models/anime.md) 中的 `ArchiveSource` /
`ArchiveResolution` 枚举转换为面向用户的文本。它们作为一个共享文件存在，而不是各页面上的私有方法，
因为有三个调用点需要它们——[`anime_edit_page.md`](anime_edit_page.md)（两个下拉框）、
[`anime_detail_page.md`](anime_detail_page.md)（只读存档卡片），以及任何未来的存档相关视图——而更早
的 `_typeLabel` 辅助函数已经在 `anime_edit_page.dart`、`anime_detail_page.dart` 和
`share_service.dart` 中重复了三份，本文件正是为了避免这种漂移。

**刻意的翻译策略。** `BD`、`DVD`、`WEB`、`TV`、`2160p`、`1080p`、`720p`、`480p` 以硬编码字面量返回：
它们是国际通用技术术语，在每个受支持的语言环境中读法完全相同，因此放进 ARB 目录只会为每一项添加四份
完全相同的副本，而译者无从决策。只有每个枚举的 `other` 成员经字符串目录解析，通过
`l10n.animeArchiveOther`。见 [`../../../../translation-guide.md`](../../../../translation-guide.md)。

枚举成员名是存储标识符而非展示字符串——落进 `anime_data.json` 的是 `fhd1080p`，用户看到的是 `1080p`。
重命名成员是数据格式变更；改这里的标签则不是。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`archiveSourceLabel`](#archivesourcelabel) | 顶层函数 | A | 把 `ArchiveSource` 渲染为面向用户的文本。 |
| [`archiveResolutionLabel`](#archiveresolutionlabel) | 顶层函数 | A | 把 `ArchiveResolution` 渲染为面向用户的文本。 |
| [`archiveQualityLabel`](#archivequalitylabel) | 顶层函数 | A | 把存档的片源与分辨率合成一个 `BD · 1080p` 标签，或 `null`。 |

## 文档

### `String archiveSourceLabel(ArchiveSource source, AppLocalizations l10n)` <a id="archivesourcelabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/archive_labels.dart`（第 10 行）
- **用途：** 把 `ArchiveSource` 枚举值映射为下拉框和详情卡片中显示的文本。
- **输入：** `source`；`l10n` — 仅用于 `other` 成员。
- **返回：** `String` — `'BD'`、`'DVD'`、`'WEB'`、`'TV'` 或 `l10n.animeArchiveOther`。
- **副作用：** 无。
- **算法：** 对 `ArchiveSource.values` 穷举 `switch`（无 `default`，因此新增枚举成员会在此处编译报错，而不是静默缺失标签）。
- **用法：**
  ```dart
  ...ArchiveSource.values.map(
    (s) => DropdownMenuItem(value: s, child: Text(archiveSourceLabel(s, l10n))),
  ),
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，本地存档片源下拉框）

### `String archiveResolutionLabel(ArchiveResolution resolution, AppLocalizations l10n)` <a id="archiveresolutionlabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/archive_labels.dart`（第 31 行）
- **用途：** 把 `ArchiveResolution` 枚举值映射为下拉框和详情卡片中显示的文本。
- **输入：** `resolution`；`l10n` — 仅用于 `other` 成员。
- **返回：** `String` — `'2160p'`、`'1080p'`、`'720p'`、`'480p'` 或 `l10n.animeArchiveOther`。
- **副作用：** 无。
- **算法：** 穷举 `switch`，与 `archiveSourceLabel` 形态相同。
- **备注：** 枚举成员带有画质档次前缀（`uhd`/`fhd`/`hd`/`sd`），标签刻意丢弃它——前缀用于消歧标识符，数字才是用户认得的东西。

### `String? archiveQualityLabel(AnimeLocalArchive archive, AppLocalizations l10n)` <a id="archivequalitylabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/archive_labels.dart`（第 55 行）
- **用途：** 产出动画详情页显示的单个组合画质字符串。
- **输入：** `archive`；`l10n`。
- **返回：** `String?` — 两半都设置时为 `'BD · 1080p'`，只设置了一半时就是那一半，两半都没有时为 `null`，
  因此调用方永远不会渲染出悬空的 `·` 分隔符。
- **副作用：** 无。
- **算法：** 用集合 `if` 把非 null 的两半收集进列表，列表为空时返回 `null`，否则返回 `parts.join(' · ')`。
- **用法：**
  ```dart
  final details = <String>[
    ?archiveQualityLabel(archive, l10n),
    if (archive.copies != null) l10n.animeArchiveCopiesValue(archive.copies!),
    if (archive.location != null && archive.location!.isNotEmpty) archive.location!,
  ];
  ```
  （`lib/features/anime/views/anime_detail_page.dart` 的 `_buildLocalArchiveCard`——前导 `?` 是 Dart
  的 null-aware element，标签为 `null` 时丢弃该条目）
