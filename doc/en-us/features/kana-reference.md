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

## Layout

The page is adaptive. On a window the app-wide split rule allows, and wide enough to hold two kana
tables of at least 330 logical pixels, it lays its sections out in two columns — the tall gojuon
and yoon tables on the left, the short dakuten table and the rule cards on the right — and puts the
script switch beside the search field instead of above it. Otherwise it keeps the original single
stacked column. The rule cards flow one or two across on their own, measured against whatever width
the section is actually given.

The practical result: a Z Fold 8 unfolded in landscape, a Fold 8 Ultra either way, a Pixel 10 Pro
Fold, a tablet in landscape and a desktop window get two columns; the Fold 8 in portrait, the
narrower unfolded foldables, tablets in portrait and every phone keep one. Both gates and the
numbers behind them are in [`../adaptive-layout.md`](../adaptive-layout.md).

This page used to carry the only hardcoded width breakpoint left in `lib/` — an inline
`constraints.maxWidth >= 720` for the rule cards. 1.5.4 routed it through the shared column
arithmetic, which resolved that exception without changing what a tablet in portrait renders.
