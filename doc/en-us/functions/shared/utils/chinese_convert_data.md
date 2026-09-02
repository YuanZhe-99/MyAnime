# lib/shared/utils/chinese_convert_data.dart

A **generated** data file holding the two Simplified ↔ Traditional character tables that
[`chinese_convert.md`](chinese_convert.md) looks up against. It has no functions, constructors or
getters, and therefore no `/// Purpose:` comments and no index rows: it declares exactly two
`const String`s.

| Constant | Contents |
|---|---|
| `kSimplifiedToTraditionalPairs` | Interleaved rune pairs: simplified, traditional, simplified, traditional, … |
| `kTraditionalToSimplifiedPairs` | Interleaved rune pairs: traditional, simplified, … |

Do not edit it by hand. It is produced by `tool/gen_chinese_convert.dart` from three inputs kept in
the repo:

- `tool/data/opencc/STCharacters.txt` and `tool/data/opencc/TSCharacters.txt` — the OpenCC
  character dictionaries (Apache License 2.0, © Carbo Kuo and contributors), fetched from
  `https://raw.githubusercontent.com/BYVoid/OpenCC/<commit>/data/dictionary/`; the commit is
  recorded in the generated header;
- `tool/data/legacy_st_pairs.txt` — the app's pre-1.5.7 hand-typed table, one `简\t繁` pair per
  line, exported once.

Merge rules: Simplified→Traditional keeps the legacy pair on a conflict (the legacy table was
Taiwan-flavoured: 里→裡, 着→著) and adds every OpenCC key it lacked; Traditional→Simplified takes
OpenCC's first value (the many-to-one canonical: 乾/幹→干, 髮/發→发) and falls back to the reversed
legacy pairs only for keys OpenCC does not list. Multi-rune entries and identity pairs are dropped.
Non-BMP characters are written as `\u{XXXXX}` escapes so the file stays safe for tooling that counts
UTF-16 units. Pairs are sorted by key, so regenerating with unchanged inputs yields an identical
file — `test/chinese_convert_test.dart` checks that both strings hold whole pairs with unique keys.

Regenerate only when bumping OpenCC:

```bash
dart run tool/gen_chinese_convert.dart --commit <sha>
```

The Apache-2.0 attribution appears in the file header and on the in-app license page
([`../../features/settings/views/license_page.md`](../../features/settings/views/license_page.md)).
