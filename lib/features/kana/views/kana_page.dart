import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum _KanaScript { hiragana, katakana }

class KanaPage extends StatefulWidget {
  const KanaPage({super.key});

  @override
  State<KanaPage> createState() => _KanaPageState();
}

class _KanaPageState extends State<KanaPage> {
  final _searchController = TextEditingController();
  _KanaScript _script = _KanaScript.hiragana;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty ? <_KanaEntry>[] : _matchingEntries(query);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kanaTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_KanaScript>(
                    segments: [
                      ButtonSegment(
                        value: _KanaScript.hiragana,
                        icon: const Icon(Icons.text_fields, size: 18),
                        label: Text(l10n.kanaScriptHiragana),
                      ),
                      ButtonSegment(
                        value: _KanaScript.katakana,
                        icon: const Icon(Icons.title, size: 18),
                        label: Text(l10n.kanaScriptKatakana),
                      ),
                    ],
                    selected: {_script},
                    onSelectionChanged: (selection) {
                      setState(() => _script = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.kanaSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 20),
                  if (query.isEmpty) ...[
                    _buildKanaTable(theme, l10n.kanaBasicSection, const [
                      'a',
                      'i',
                      'u',
                      'e',
                      'o',
                    ], _basicRows),
                    const SizedBox(height: 20),
                    _buildKanaTable(theme, l10n.kanaVoicedSection, const [
                      'a',
                      'i',
                      'u',
                      'e',
                      'o',
                    ], _voicedRows),
                    const SizedBox(height: 20),
                    _buildKanaTable(theme, l10n.kanaYoonSection, const [
                      'ya',
                      'yu',
                      'yo',
                    ], _yoonRows),
                  ] else
                    _buildSearchResults(theme, l10n, matches),
                  const SizedBox(height: 24),
                  _buildRules(theme, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_KanaEntry> _matchingEntries(String query) {
    final seen = <String>{};
    final entries = <_KanaEntry>[];
    for (final row in [..._basicRows, ..._voicedRows, ..._yoonRows]) {
      for (final entry in row.entries) {
        if (entry == null || !entry.matches(query)) continue;
        final key = '${entry.hiragana}:${entry.romaji}';
        if (seen.add(key)) entries.add(entry);
      }
    }
    return entries;
  }

  Widget _buildKanaTable(
    ThemeData theme,
    String title,
    List<String> columns,
    List<_KanaRow> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, Icons.grid_on_outlined, title),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildHeaderRow(theme, columns),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              for (var i = 0; i < rows.length; i++) ...[
                _buildKanaRow(theme, rows[i]),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    indent: 44,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(ThemeData theme, List<String> columns) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 44),
          for (final column in columns)
            Expanded(
              child: Center(
                child: Text(
                  column,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKanaRow(ThemeData theme, _KanaRow row) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: Text(
              row.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final entry in row.entries) _buildKanaCell(theme, entry),
      ],
    );
  }

  Widget _buildKanaCell(ThemeData theme, _KanaEntry? entry) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: entry == null
            ? const SizedBox(height: 58)
            : Tooltip(
                message: '${entry.kana(_script)} / ${entry.romaji}',
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.52,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.kana(_script),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.romaji,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSearchResults(
    ThemeData theme,
    AppLocalizations l10n,
    List<_KanaEntry> matches,
  ) {
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            l10n.kanaNoMatches,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          Icons.manage_search_outlined,
          l10n.kanaSearchResults(matches.length),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: matches
              .map(
                (entry) =>
                    SizedBox(width: 92, child: _buildResultTile(theme, entry)),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResultTile(ThemeData theme, _KanaEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.kana(_script),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.romaji,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRules(ThemeData theme, AppLocalizations l10n) {
    final rules = [
      _KanaRule(
        Icons.graphic_eq_outlined,
        l10n.kanaRuleMoraTitle,
        l10n.kanaRuleMoraBody,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      _KanaRule(
        Icons.record_voice_over_outlined,
        l10n.kanaRuleVowelsTitle,
        l10n.kanaRuleVowelsBody,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      _KanaRule(
        Icons.blur_on_outlined,
        l10n.kanaRuleDakutenTitle,
        l10n.kanaRuleDakutenBody,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      _KanaRule(
        Icons.join_inner_outlined,
        l10n.kanaRuleYoonTitle,
        l10n.kanaRuleYoonBody,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      _KanaRule(
        Icons.compress_outlined,
        l10n.kanaRuleSokuonTitle,
        l10n.kanaRuleSokuonBody,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      _KanaRule(
        Icons.keyboard_double_arrow_right_outlined,
        l10n.kanaRuleLongVowelsTitle,
        l10n.kanaRuleLongVowelsBody,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      _KanaRule(
        Icons.waves_outlined,
        l10n.kanaRuleNTitle,
        l10n.kanaRuleNBody,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final width = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              theme,
              Icons.tips_and_updates_outlined,
              l10n.kanaRulesSection,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final rule in rules)
                  SizedBox(width: width, child: _buildRuleCard(theme, rule)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRuleCard(ThemeData theme, _KanaRule rule) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: rule.iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(rule.icon, size: 21, color: rule.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rule.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _KanaEntry {
  final String hiragana;
  final String katakana;
  final String romaji;

  const _KanaEntry(this.hiragana, this.katakana, this.romaji);

  String kana(_KanaScript script) {
    return switch (script) {
      _KanaScript.hiragana => hiragana,
      _KanaScript.katakana => katakana,
    };
  }

  bool matches(String query) {
    return hiragana.contains(query) ||
        katakana.contains(query) ||
        romaji.toLowerCase().contains(query);
  }
}

class _KanaRow {
  final String label;
  final List<_KanaEntry?> entries;

  const _KanaRow(this.label, this.entries);
}

class _KanaRule {
  final IconData icon;
  final String title;
  final String body;
  final Color iconBackground;
  final Color iconColor;

  const _KanaRule(
    this.icon,
    this.title,
    this.body,
    this.iconBackground,
    this.iconColor,
  );
}

const _basicRows = [
  _KanaRow('v', [
    _KanaEntry('あ', 'ア', 'a'),
    _KanaEntry('い', 'イ', 'i'),
    _KanaEntry('う', 'ウ', 'u'),
    _KanaEntry('え', 'エ', 'e'),
    _KanaEntry('お', 'オ', 'o'),
  ]),
  _KanaRow('k', [
    _KanaEntry('か', 'カ', 'ka'),
    _KanaEntry('き', 'キ', 'ki'),
    _KanaEntry('く', 'ク', 'ku'),
    _KanaEntry('け', 'ケ', 'ke'),
    _KanaEntry('こ', 'コ', 'ko'),
  ]),
  _KanaRow('s', [
    _KanaEntry('さ', 'サ', 'sa'),
    _KanaEntry('し', 'シ', 'shi'),
    _KanaEntry('す', 'ス', 'su'),
    _KanaEntry('せ', 'セ', 'se'),
    _KanaEntry('そ', 'ソ', 'so'),
  ]),
  _KanaRow('t', [
    _KanaEntry('た', 'タ', 'ta'),
    _KanaEntry('ち', 'チ', 'chi'),
    _KanaEntry('つ', 'ツ', 'tsu'),
    _KanaEntry('て', 'テ', 'te'),
    _KanaEntry('と', 'ト', 'to'),
  ]),
  _KanaRow('n', [
    _KanaEntry('な', 'ナ', 'na'),
    _KanaEntry('に', 'ニ', 'ni'),
    _KanaEntry('ぬ', 'ヌ', 'nu'),
    _KanaEntry('ね', 'ネ', 'ne'),
    _KanaEntry('の', 'ノ', 'no'),
  ]),
  _KanaRow('h', [
    _KanaEntry('は', 'ハ', 'ha'),
    _KanaEntry('ひ', 'ヒ', 'hi'),
    _KanaEntry('ふ', 'フ', 'fu'),
    _KanaEntry('へ', 'ヘ', 'he'),
    _KanaEntry('ほ', 'ホ', 'ho'),
  ]),
  _KanaRow('m', [
    _KanaEntry('ま', 'マ', 'ma'),
    _KanaEntry('み', 'ミ', 'mi'),
    _KanaEntry('む', 'ム', 'mu'),
    _KanaEntry('め', 'メ', 'me'),
    _KanaEntry('も', 'モ', 'mo'),
  ]),
  _KanaRow('y', [
    _KanaEntry('や', 'ヤ', 'ya'),
    null,
    _KanaEntry('ゆ', 'ユ', 'yu'),
    null,
    _KanaEntry('よ', 'ヨ', 'yo'),
  ]),
  _KanaRow('r', [
    _KanaEntry('ら', 'ラ', 'ra'),
    _KanaEntry('り', 'リ', 'ri'),
    _KanaEntry('る', 'ル', 'ru'),
    _KanaEntry('れ', 'レ', 're'),
    _KanaEntry('ろ', 'ロ', 'ro'),
  ]),
  _KanaRow('w', [
    _KanaEntry('わ', 'ワ', 'wa'),
    null,
    null,
    null,
    _KanaEntry('を', 'ヲ', 'o/wo'),
  ]),
  _KanaRow('n', [_KanaEntry('ん', 'ン', 'n'), null, null, null, null]),
];

const _voicedRows = [
  _KanaRow('g', [
    _KanaEntry('が', 'ガ', 'ga'),
    _KanaEntry('ぎ', 'ギ', 'gi'),
    _KanaEntry('ぐ', 'グ', 'gu'),
    _KanaEntry('げ', 'ゲ', 'ge'),
    _KanaEntry('ご', 'ゴ', 'go'),
  ]),
  _KanaRow('z', [
    _KanaEntry('ざ', 'ザ', 'za'),
    _KanaEntry('じ', 'ジ', 'ji'),
    _KanaEntry('ず', 'ズ', 'zu'),
    _KanaEntry('ぜ', 'ゼ', 'ze'),
    _KanaEntry('ぞ', 'ゾ', 'zo'),
  ]),
  _KanaRow('d', [
    _KanaEntry('だ', 'ダ', 'da'),
    _KanaEntry('ぢ', 'ヂ', 'ji'),
    _KanaEntry('づ', 'ヅ', 'zu'),
    _KanaEntry('で', 'デ', 'de'),
    _KanaEntry('ど', 'ド', 'do'),
  ]),
  _KanaRow('b', [
    _KanaEntry('ば', 'バ', 'ba'),
    _KanaEntry('び', 'ビ', 'bi'),
    _KanaEntry('ぶ', 'ブ', 'bu'),
    _KanaEntry('べ', 'ベ', 'be'),
    _KanaEntry('ぼ', 'ボ', 'bo'),
  ]),
  _KanaRow('p', [
    _KanaEntry('ぱ', 'パ', 'pa'),
    _KanaEntry('ぴ', 'ピ', 'pi'),
    _KanaEntry('ぷ', 'プ', 'pu'),
    _KanaEntry('ぺ', 'ペ', 'pe'),
    _KanaEntry('ぽ', 'ポ', 'po'),
  ]),
];

const _yoonRows = [
  _KanaRow('k', [
    _KanaEntry('きゃ', 'キャ', 'kya'),
    _KanaEntry('きゅ', 'キュ', 'kyu'),
    _KanaEntry('きょ', 'キョ', 'kyo'),
  ]),
  _KanaRow('s', [
    _KanaEntry('しゃ', 'シャ', 'sha'),
    _KanaEntry('しゅ', 'シュ', 'shu'),
    _KanaEntry('しょ', 'ショ', 'sho'),
  ]),
  _KanaRow('t', [
    _KanaEntry('ちゃ', 'チャ', 'cha'),
    _KanaEntry('ちゅ', 'チュ', 'chu'),
    _KanaEntry('ちょ', 'チョ', 'cho'),
  ]),
  _KanaRow('n', [
    _KanaEntry('にゃ', 'ニャ', 'nya'),
    _KanaEntry('にゅ', 'ニュ', 'nyu'),
    _KanaEntry('にょ', 'ニョ', 'nyo'),
  ]),
  _KanaRow('h', [
    _KanaEntry('ひゃ', 'ヒャ', 'hya'),
    _KanaEntry('ひゅ', 'ヒュ', 'hyu'),
    _KanaEntry('ひょ', 'ヒョ', 'hyo'),
  ]),
  _KanaRow('m', [
    _KanaEntry('みゃ', 'ミャ', 'mya'),
    _KanaEntry('みゅ', 'ミュ', 'myu'),
    _KanaEntry('みょ', 'ミョ', 'myo'),
  ]),
  _KanaRow('r', [
    _KanaEntry('りゃ', 'リャ', 'rya'),
    _KanaEntry('りゅ', 'リュ', 'ryu'),
    _KanaEntry('りょ', 'リョ', 'ryo'),
  ]),
  _KanaRow('g', [
    _KanaEntry('ぎゃ', 'ギャ', 'gya'),
    _KanaEntry('ぎゅ', 'ギュ', 'gyu'),
    _KanaEntry('ぎょ', 'ギョ', 'gyo'),
  ]),
  _KanaRow('j', [
    _KanaEntry('じゃ', 'ジャ', 'ja'),
    _KanaEntry('じゅ', 'ジュ', 'ju'),
    _KanaEntry('じょ', 'ジョ', 'jo'),
  ]),
  _KanaRow('b', [
    _KanaEntry('びゃ', 'ビャ', 'bya'),
    _KanaEntry('びゅ', 'ビュ', 'byu'),
    _KanaEntry('びょ', 'ビョ', 'byo'),
  ]),
  _KanaRow('p', [
    _KanaEntry('ぴゃ', 'ピャ', 'pya'),
    _KanaEntry('ぴゅ', 'ピュ', 'pyu'),
    _KanaEntry('ぴょ', 'ピョ', 'pyo'),
  ]),
];
