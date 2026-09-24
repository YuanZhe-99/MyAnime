import '../services/anime_search_service.dart';

/// Version of [animeCategories]. Bumped whenever an id is added, and part of
/// every cached AI classification's fingerprint, so a new taxonomy re-queues
/// classification. Ids are never renamed or removed once shipped.
const int categoryTaxonomyVersion = 1;

/// One category in the app's own taxonomy.
class AnimeCategory {
  /// Stable id, stored in `Anime.categories` and in the AI cache.
  final String id;

  /// One-line English description, used in model prompts only; the UI uses
  /// the localized label.
  final String description;

  /// Purpose: Create a category.
  /// Inputs: `id`, `description`.
  /// Returns: A new `AnimeCategory`.
  /// Side effects: None.
  /// Notes: Only [animeCategories] constructs these.
  const AnimeCategory(this.id, this.description);
}

/// The v1 taxonomy, approved as proposed (D4). There is deliberately no adult
/// or fan-service category: Apple's acceptable-use rules for Foundation Models
/// prohibit generating such content, and the models' guardrails refuse it.
const List<AnimeCategory> animeCategories = [
  AnimeCategory('action', 'fights, battles and physical conflict'),
  AnimeCategory('adventure', 'journeys, quests and exploration'),
  AnimeCategory('comedy', 'played mainly for laughs'),
  AnimeCategory('drama', 'serious, emotional character stories'),
  AnimeCategory('romance', 'love stories and relationships'),
  AnimeCategory('slice_of_life', 'everyday life with little overarching plot'),
  AnimeCategory('fantasy', 'magic, mythical creatures, invented worlds'),
  AnimeCategory(
    'isekai',
    'a character transported or reborn into another world',
  ),
  AnimeCategory('sci_fi', 'science fiction: technology, space, the future'),
  AnimeCategory('mecha', 'giant robots or piloted machines'),
  AnimeCategory('mystery', 'solving crimes, puzzles or secrets'),
  AnimeCategory('suspense', 'thrillers built on tension'),
  AnimeCategory('horror', 'meant to frighten'),
  AnimeCategory('psychological', 'the inner workings of the mind'),
  AnimeCategory('supernatural', 'ghosts, spirits, youkai or special powers'),
  AnimeCategory('sports', 'athletes, teams and competition'),
  AnimeCategory('music', 'musicians, bands and idols'),
  AnimeCategory('school', 'set mainly at a school'),
  AnimeCategory('historical', 'set in a real historical period'),
  AnimeCategory('military', 'armies, soldiers and war'),
  AnimeCategory('gourmet', 'cooking and food'),
  AnimeCategory('healing', 'iyashikei: calm, soothing and gentle'),
  AnimeCategory('magical_girl', 'girls who transform to fight with magic'),
];

/// Every id in [animeCategories], for validating model output and user data.
final Set<String> animeCategoryIds = {for (final c in animeCategories) c.id};

/// Genre and tag names from AniList, MyAnimeList (genres and themes) and
/// bangumi.tv, folded with `AnimeSearchService.foldTitle` (lowercase, no
/// spaces or punctuation, Simplified Chinese), mapped to category ids. Names
/// with no fitting category (for example `Ecchi`) are simply absent.
const Map<String, String> _genreSynonyms = {
  // English (AniList and MyAnimeList).
  'action': 'action',
  'martialarts': 'action',
  'adventure': 'adventure',
  'comedy': 'comedy',
  'gagHumor': 'comedy',
  'drama': 'drama',
  'romance': 'romance',
  'lovepolygon': 'romance',
  'sliceoflife': 'slice_of_life',
  'fantasy': 'fantasy',
  'isekai': 'isekai',
  'reincarnation': 'isekai',
  'scifi': 'sci_fi',
  'space': 'sci_fi',
  'timetravel': 'sci_fi',
  'mecha': 'mecha',
  'mystery': 'mystery',
  'detective': 'mystery',
  'suspense': 'suspense',
  'thriller': 'suspense',
  'horror': 'horror',
  'psychological': 'psychological',
  'supernatural': 'supernatural',
  'superpower': 'supernatural',
  'vampire': 'supernatural',
  'sports': 'sports',
  'teamsports': 'sports',
  'combatsports': 'sports',
  'music': 'music',
  'idolsfemale': 'music',
  'idolsmale': 'music',
  'performingarts': 'music',
  'school': 'school',
  'historical': 'historical',
  'samurai': 'historical',
  'military': 'military',
  'gourmet': 'gourmet',
  'iyashikei': 'healing',
  'mahoushoujo': 'magical_girl',
  // Chinese (bangumi.tv tags; Traditional folds to Simplified).
  '战斗': 'action',
  '热血': 'action',
  '冒险': 'adventure',
  '搞笑': 'comedy',
  '喜剧': 'comedy',
  '剧情': 'drama',
  '恋爱': 'romance',
  '日常': 'slice_of_life',
  '奇幻': 'fantasy',
  '魔幻': 'fantasy',
  '异世界': 'isekai',
  '科幻': 'sci_fi',
  '机战': 'mecha',
  '机器人': 'mecha',
  '悬疑': 'mystery',
  '推理': 'mystery',
  '惊悚': 'suspense',
  '恐怖': 'horror',
  '心理': 'psychological',
  '灵异': 'supernatural',
  '超能力': 'supernatural',
  '运动': 'sports',
  '体育': 'sports',
  '竞技': 'sports',
  '音乐': 'music',
  '偶像': 'music',
  '校园': 'school',
  '历史': 'historical',
  '战争': 'military',
  '军事': 'military',
  '美食': 'gourmet',
  '治愈': 'healing',
  '魔法少女': 'magical_girl',
};

/// The synonym table keyed exactly as tags fold, built once.
final Map<String, String> _foldedSynonyms = {
  for (final e in _genreSynonyms.entries)
    AnimeSearchService.foldTitle(e.key): e.value,
};

/// Purpose: Map source genres and tags onto category ids.
/// Inputs: `genres` — `externalMeta.genres` as stored.
/// Returns: `List<String>` — category ids in taxonomy order, deduplicated.
/// Side effects: None.
/// Notes: Unknown tags are ignored. Works on every platform and in store
/// builds, since it only reads data already on the record.
List<String> mapGenresToCategories(Iterable<String> genres) {
  final hit = <String>{};
  for (final g in genres) {
    final id = _foldedSynonyms[AnimeSearchService.foldTitle(g)];
    if (id != null) hit.add(id);
  }
  return [
    for (final c in animeCategories)
      if (hit.contains(c.id)) c.id,
  ];
}
