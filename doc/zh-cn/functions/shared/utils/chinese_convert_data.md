# lib/shared/utils/chinese_convert_data.dart

一个**生成**的数据文件，保存 [`chinese_convert.md`](chinese_convert.md) 查表所用的两张简繁字符表。它没有函数、
构造函数或 getter，因此没有 `/// Purpose:` 注释，也没有索引行：它只声明两个 `const String`。

| 常量 | 内容 |
|---|---|
| `kSimplifiedToTraditionalPairs` | 交错的码点对：简体、繁体、简体、繁体、…… |
| `kTraditionalToSimplifiedPairs` | 交错的码点对：繁体、简体、…… |

不要手工编辑。它由 `tool/gen_chinese_convert.dart` 从仓库内保留的三个输入生成：

- `tool/data/opencc/STCharacters.txt` 与 `tool/data/opencc/TSCharacters.txt`——OpenCC 的字符字典
  （Apache License 2.0，© Carbo Kuo 与贡献者），取自
  `https://raw.githubusercontent.com/BYVoid/OpenCC/<commit>/data/dictionary/`；commit 记录在生成文件的头部；
- `tool/data/legacy_st_pairs.txt`——应用 1.5.7 之前的手打表，每行一对 `简\t繁`，导出过一次。

合并规则：简转繁在冲突时保留旧表的选择（旧表偏台湾用法：里→裡、着→著），并补上 OpenCC 有而旧表没有的每个
字；繁转简取 OpenCC 的第一个候选（多对一的规范方向：乾/幹→干、髮/發→发），只在 OpenCC 未列出的字上回退到旧
表的反向对。多码点条目与恒等对被丢弃。非 BMP 字符写成 `\u{XXXXX}` 转义，使文件对按 UTF-16 单元计数的工具保持
安全。各对按键排序，因此输入不变时重新生成得到完全相同的文件——`test/chinese_convert_test.dart` 检查两个字符串
都由完整的对组成且键唯一。

只在升级 OpenCC 时重新生成：

```bash
dart run tool/gen_chinese_convert.dart --commit <sha>
```

Apache-2.0 的署名出现在文件头部与应用内许可证页面
（[`../../features/settings/views/license_page.md`](../../features/settings/views/license_page.md)）。
