# Kana Quick Reference

`lib/features/kana/views/kana_page.dart` is a **UI-only** reference module. It does not read or
write any anime data and is **not synced** — it doesn't appear anywhere in the persisted-data
inventory in [`../data-formats.md`](../data-formats.md) because it has no persisted state of its
own beyond ordinary widget state.

It occupies the fourth of the app's five bottom-navigation tabs (see
[`../architecture.md`](../architecture.md)).

## Contents

- Hiragana and katakana segmented switching.
- Kana and romaji search.
- Basic gojuon table.
- Dakuten and handakuten table.
- Yoon combinations.
- Pronunciation rule cards for mora rhythm, stable vowels, sokuon, long vowels, and nasal sounds.
