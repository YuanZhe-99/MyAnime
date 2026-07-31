# lib/features/settings/views/privacy_policy_page.dart

`PrivacyPolicyPage` 是从设置 -> 关于 -> 隐私政策到达的静态、感知语言区域的设置子页（见 `functions/features/settings/views/settings_page.md`）。它是没有服务依赖的 `StatelessWidget`：`build` 经 `Localizations.localeOf(context)` 解析当前 `Locale` 并把它交给文件中唯一一段真实逻辑 `_getText`，后者从四个硬编码隐私政策字符串常量（`_en`、`_zh`、`_zhTW`、`_ja`）中选一个渲染到可滚动 `SelectableText` 中。政策文本本身记录应用实际的网络/数据行为（无分析、仅在用户配置时 WebDAV 同步、仅本地备份）——它用散文描述的机制见 [`../../../backup-restore.md`](../../../../backup-restore.md) 和 [`../../../sync.md`](../../../../sync.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `PrivacyPolicyPage({super.key})` | 构造函数（`PrivacyPolicyPage`） | B | 创建隐私政策页实例。 |
| `build` | 方法（组件构建） | B | 解析当前语言区域并渲染匹配的静态政策文本。 |
| [`_getText`](#gettext) | 方法（`PrivacyPolicyPage`） | A | 选择语言区域合适的静态隐私政策文本。 |

## 文档

### `String _getText(Locale locale)` <a id="gettext"></a>
- **种类：** `PrivacyPolicyPage` 的方法
- **来源：** `lib/features/settings/views/privacy_policy_page.dart`（第 41 行）
- **用途：** 基于组件树的当前语言区域，选择显示哪个语言变体的静态隐私政策文本。
- **输入：** `locale` — 在 `build` 中经 `Localizations.localeOf(context)` 解析的 `Locale`。
- **返回：** 类中下方定义的四个静态 `String` 常量之一：`_zhTW`、`_zh`、`_ja` 或 `_en`。
- **副作用：** 无。
- **算法：**
  1. `locale.languageCode == 'zh'` **且** `locale.countryCode == 'TW'` 时，立即返回 `_zhTW`（繁体中文）——这个特定检查先运行，因为它是比下面普通 `'zh'` 情形更窄的匹配。
  2. 否则对 `locale.languageCode` 做 `switch`：`'zh'` -> `_zh`（简体中文），`'ja'` -> `_ja`（日语）。
  3. 任何其他语言代码，包括 switch 中无匹配的，落入 `default` 并返回 `_en`（英语）。
- **用法：**
  ```dart
  // From PrivacyPolicyPage.build:
  final locale = Localizations.localeOf(context);
  final text = _getText(locale);
  ```
- **备注：** 繁体中文分支要求 `languageCode == 'zh'` **且** `countryCode == 'TW'`；country code 不同或缺省的 `zh` 语言区域（如 `zh_CN`，或无 country 的裸 `zh`）不命中第一个检查，而是落入 `switch`，匹配普通 `'zh'` case 并返回 `_zh`（简体），不是 `_zhTW`。
