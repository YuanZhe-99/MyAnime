# lib/features/ai/services/insight_language.dart

`InsightLanguage`（1.9.1，移植自 MyDevice!!!!!）：按界面语言区域选择请求语言——简体或繁体中文（转换为界面所用变体）、日语或英语——并对每个已校验的句子做中文繁简转换。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `InsightLanguage` | 声明 | B | 创建一种洞察语言。 |
| `forLocale` | 声明 | B | 按界面语言区域选择请求语言。 |
| `finish` | 声明 | B | 对已校验的句子做后处理（中文繁简转换）。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_language.dart` 报告 3，每个一行。
