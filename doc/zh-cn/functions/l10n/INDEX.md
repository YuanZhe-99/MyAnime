# lib/l10n/ — 生成的本地化代码

`lib/l10n/` 中的四个文件（`app_localizations.dart`、`app_localizations_en.dart`、`app_localizations_ja.dart`、`app_localizations_zh.dart`）由 Flutter 的 `gen-l10n` 工具从 ARB 模板（`app_en.arb`、`app_ja.arb`、`app_zh.arb`、`app_zh_TW.arb`）生成。它们被纳入源码管理但不是手写的，并且——与本仓库中其他每个文件不同——不带 `/// Purpose:` 函数解释层注释（已确认：`grep -rc 'Purpose:' lib/l10n/` 在全部四个文件中报告零匹配，而 `lib/` 其余部分有 660 个）。

每个语言区域子类（`AppLocalizationsEn`、`AppLocalizationsJa`、`AppLocalizationsZh`）实现抽象 `AppLocalizations` 基类，每个在 ARB 模板中定义的可翻译键对应一个平凡的单字符串/复数 getter——数百个近乎相同的单行 Tier B getter。因为它们是生成而非编写的，且除"返回这个键的本地化字符串"外没有算法或用法，本文档集不逐一列举它们。字符串目录的权威、人工维护的事实来源是 `lib/l10n/app_en.arb`（模板 ARB 文件）；编辑任何 ARB 文件后，按本仓库的 `AGENTS.md` 用 `flutter gen-l10n` 重新生成此代码。

| 源文件 | 种类 | 声明 | Tier |
|---|---|---|---|
| `lib/l10n/app_localizations.dart` | 生成的抽象基类 + 委托 | 基类、`LocalizationsDelegate` 查找、`of(context)`、`_lookupAppLocalizations` | B（生成） |
| `lib/l10n/app_localizations_en.dart` | 生成的语言区域子类 | 每个 ARB 键一个 getter | B（生成） |
| `lib/l10n/app_localizations_ja.dart` | 生成的语言区域子类 | 每个 ARB 键一个 getter | B（生成） |
| `lib/l10n/app_localizations_zh.dart` | 生成的语言区域子类 | 每个 ARB 键一个 getter | B（生成） |

本目录中的声明不计入 [../INDEX.md](../INDEX.md) 跟踪的 660 个手写声明；这里列出仅为函数索引的完整性。
