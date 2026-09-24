import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../anime/models/anime.dart';
import '../../anime/services/series_service.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../categories/services/category_service.dart';

/// The ranking weights, in one place so they can be tuned and tested.
abstract final class RecommendationWeights {
  /// The previous member of the candidate's series is completed.
  static const nextInSeries = 3.0;

  /// ...and that member was rated [highRating] or higher.
  static const nextInSeriesRatedHigh = 1.0;

  /// A rating at or above this counts as "rated highly".
  static const highRating = 8.0;

  /// Multiplies the cosine of the taste profile and the candidate's
  /// categories.
  static const categoryMatch = 2.0;

  /// Multiplies the best studio affinity, which is capped at 1.
  static const studioMatch = 0.5;

  /// Multiplies the external average minus [externalPivot], clamped to ±2.
  static const externalScore = 0.3;

  /// The external score treated as neutral.
  static const externalPivot = 7.0;

  /// Being watched with aired but unwatched episodes.
  static const catchUp = 0.8;

  /// Currently airing.
  static const airing = 0.4;
}

/// Why a candidate is recommended, rendered as a chip by the UI.
sealed class RecommendationReason {
  /// Purpose: Create a reason.
  /// Inputs: None.
  /// Returns: A reason.
  /// Side effects: None.
  /// Notes: Subclasses carry the data; the UI localizes.
  const RecommendationReason();
}

/// "Next after <title>".
final class NextAfterReason extends RecommendationReason {
  /// The completed member it follows.
  final Anime previous;

  /// Purpose: Create the reason.
  /// Inputs: `previous`.
  /// Returns: A new `NextAfterReason`.
  /// Side effects: None.
  /// Notes: None.
  const NextAfterReason(this.previous);
}

/// "Like titles you rated highly: romance, school".
final class CategoryMatchReason extends RecommendationReason {
  /// The shared category ids, strongest first, at most two.
  final List<String> categoryIds;

  /// Purpose: Create the reason.
  /// Inputs: `categoryIds`.
  /// Returns: A new `CategoryMatchReason`.
  /// Side effects: None.
  /// Notes: None.
  const CategoryMatchReason(this.categoryIds);
}

/// "Same studio as <title>".
final class SameStudioReason extends RecommendationReason {
  /// The liked record from the same studio.
  final Anime liked;

  /// The studio.
  final String studio;

  /// Purpose: Create the reason.
  /// Inputs: `liked`, `studio`.
  /// Returns: A new `SameStudioReason`.
  /// Side effects: None.
  /// Notes: None.
  const SameStudioReason(this.liked, this.studio);
}

/// "AniList 8.9".
final class ExternalScoreReason extends RecommendationReason {
  /// The database name.
  final String source;

  /// The score on a 0-10 scale.
  final double score;

  /// Purpose: Create the reason.
  /// Inputs: `source`, `score`.
  /// Returns: A new `ExternalScoreReason`.
  /// Side effects: None.
  /// Notes: None.
  const ExternalScoreReason(this.source, this.score);
}

/// "New episodes to catch up on".
final class CatchUpReason extends RecommendationReason {
  /// Purpose: Create the reason.
  /// Inputs: None.
  /// Returns: A new `CatchUpReason`.
  /// Side effects: None.
  /// Notes: None.
  const CatchUpReason();
}

/// One ranked candidate.
@immutable
class Recommendation {
  /// The record to watch next.
  final Anime anime;

  /// The total score.
  final double score;

  /// Reasons, from the largest contribution down, at most three.
  final List<RecommendationReason> reasons;

  /// Purpose: Create a recommendation.
  /// Inputs: `anime`, `score`, `reasons`.
  /// Returns: A new `Recommendation`.
  /// Side effects: None.
  /// Notes: None.
  const Recommendation(this.anime, this.score, this.reasons);
}

/// Purpose: Read how much the user liked a record.
/// Inputs: `anime`.
/// Returns: `double` in -1..1 — from the rating when there is one
/// (`(overall − 6) / 4`), else +0.5 for completed, −0.7 for dropped, 0
/// otherwise.
/// Side effects: None.
/// Notes: None.
double preferenceOf(Anime anime) {
  final r = anime.rating?.effectiveOverall;
  if (r != null) return ((r - 6) / 4).clamp(-1.0, 1.0);
  return switch (anime.viewingStatus) {
    AnimeViewingStatus.completed => 0.5,
    AnimeViewingStatus.dropped => -0.7,
    _ => 0.0,
  };
}

/// Purpose: Report whether a record has aired episodes still unwatched.
/// Inputs: `anime`, `nowJst`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Uses the next unwatched episode's computed air time.
bool hasAiredUnwatched(Anime anime, DateTime nowJst) {
  final next = anime.nextUnwatchedEpisode;
  if (next == null) return false;
  final at = anime.getEpisodeAirDate(next);
  return at != null && !at.isAfter(nowJst);
}

/// Purpose: Report whether a record is currently airing.
/// Inputs: `anime`, `nowJst`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: The source's `RELEASING` status wins; otherwise the premiere is
/// past and the last episode is still to come.
bool isAiring(Anime anime, DateTime nowJst) {
  final status = anime.externalMeta?.status;
  if (status == 'RELEASING' || status == 'Currently Airing') return true;
  final first = anime.firstAirDate;
  final end = anime.endEpisode;
  if (first == null || end == null || first.isAfter(nowJst)) return false;
  final last = anime.getEpisodeAirDate(end);
  return last != null && last.isAfter(nowJst);
}

/// Ranks the library's own unwatched and in-progress records. Pure Dart, with
/// no model involved; the optional AI reasons are layered on by the page.
class RecommendationService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `RecommendationService._` instance.
  /// Side effects: None.
  /// Notes: None.
  const RecommendationService._();

  /// Purpose: Rank what to watch next.
  /// Inputs: `library`; `insights` — AI categories and hidden ids;
  /// `nowJst`; `limit`.
  /// Returns: `List<Recommendation>` — best first.
  /// Side effects: None.
  /// Notes: Candidates are records not started, or being watched with aired
  /// unwatched episodes, minus hidden ones. Within a series only the earliest
  /// member that is not completed can be a candidate, so season 3 is never
  /// offered before season 1. With no ratings and nothing completed (cold
  /// start) the order is series continuation, then external score, then the
  /// most recently added.
  static List<Recommendation> rank(
    List<Anime> library, {
    AiInsights? insights,
    required DateTime nowJst,
    int limit = 30,
  }) {
    final hidden = insights?.hiddenRecommendations ?? const <String>{};
    final index = SeriesIndex.build(library);
    final cats = {
      for (final a in library)
        a.id: resolveCategories(a, insights: insights).ids,
    };

    // Taste profile and studio affinity.
    final profile = <String, double>{};
    final studioPref = <String, double>{};
    final studioBest = <String, Anime>{};
    var anySignal = false;
    for (final a in library) {
      final p = preferenceOf(a);
      if (a.rating?.effectiveOverall != null ||
          a.viewingStatus == AnimeViewingStatus.completed) {
        anySignal = true;
      }
      if (p == 0) continue;
      for (final c in cats[a.id]!) {
        profile[c] = (profile[c] ?? 0) + p;
      }
      for (final s in a.externalMeta?.studios ?? const <String>[]) {
        studioPref[s] = (studioPref[s] ?? 0) + p;
        final best = studioBest[s];
        if (p > 0 && (best == null || preferenceOf(best) < p)) {
          studioBest[s] = a;
        }
      }
    }
    final norm = math.sqrt(profile.values.fold(0.0, (s, v) => s + v * v));

    // Candidates.
    final candidates = <Anime>[];
    final seenSeries = <String>{};
    for (final a in library) {
      if (hidden.contains(a.id)) continue;
      final series = index.seriesOf(a.id);
      if (series != null && series.members.length >= 2) {
        if (!seenSeries.add(series.key)) continue;
        final first = series.members
            .where((m) => m.viewingStatus != AnimeViewingStatus.completed)
            .firstOrNull;
        if (first != null &&
            !hidden.contains(first.id) &&
            _eligible(first, nowJst)) {
          candidates.add(first);
        }
        continue;
      }
      if (_eligible(a, nowJst)) candidates.add(a);
    }

    final out = <Recommendation>[];
    for (final c in candidates) {
      final contributions = <(double, RecommendationReason?)>[];
      final series = index.seriesOf(c.id);
      final prev = series?.previousOf(c.id);
      if (prev != null && prev.viewingStatus == AnimeViewingStatus.completed) {
        var s = RecommendationWeights.nextInSeries;
        if ((prev.rating?.effectiveOverall ?? 0) >=
            RecommendationWeights.highRating) {
          s += RecommendationWeights.nextInSeriesRatedHigh;
        }
        contributions.add((s, NextAfterReason(prev)));
      }
      final mine = cats[c.id]!;
      if (norm > 0 && mine.isNotEmpty) {
        var dot = 0.0;
        for (final id in mine) {
          dot += profile[id] ?? 0;
        }
        final cosine = dot / (norm * math.sqrt(mine.length.toDouble()));
        final shared = [
          for (final id in mine)
            if ((profile[id] ?? 0) > 0) id,
        ]..sort((x, y) => profile[y]!.compareTo(profile[x]!));
        contributions.add((
          RecommendationWeights.categoryMatch * cosine,
          shared.isEmpty ? null : CategoryMatchReason(shared.take(2).toList()),
        ));
      }
      String? bestStudio;
      var bestAffinity = double.negativeInfinity;
      for (final s in c.externalMeta?.studios ?? const <String>[]) {
        final v = studioPref[s];
        if (v != null && v > bestAffinity) {
          bestAffinity = v;
          bestStudio = s;
        }
      }
      if (bestStudio != null) {
        final affinity = bestAffinity.clamp(-1.0, 1.0);
        final liked = studioBest[bestStudio];
        contributions.add((
          RecommendationWeights.studioMatch * affinity,
          affinity > 0 && liked != null && liked.id != c.id
              ? SameStudioReason(liked, bestStudio)
              : null,
        ));
      }
      final ext = c.externalMeta?.averageNormalizedScore;
      if (ext != null) {
        final top = _bestExternal(c);
        contributions.add((
          RecommendationWeights.externalScore *
              (ext - RecommendationWeights.externalPivot).clamp(-2.0, 2.0),
          top,
        ));
      }
      if (c.viewingStatus == AnimeViewingStatus.watching &&
          hasAiredUnwatched(c, nowJst)) {
        contributions.add((
          RecommendationWeights.catchUp,
          const CatchUpReason(),
        ));
      }
      if (isAiring(c, nowJst)) {
        contributions.add((RecommendationWeights.airing, null));
      }
      final score = contributions.fold(0.0, (s, e) => s + e.$1);
      final reasons = [
        for (final e in ([
          ...contributions,
        ]..sort((x, y) => y.$1.compareTo(x.$1))))
          if (e.$2 != null && e.$1 > 0) e.$2!,
      ].take(3).toList();
      out.add(Recommendation(c, score, reasons));
    }

    if (!anySignal) {
      // Cold start: continuation, then external score, then newest added.
      int rankOf(Recommendation r) =>
          r.reasons.any((x) => x is NextAfterReason) ? 0 : 1;
      out.sort((a, b) {
        final c = rankOf(a).compareTo(rankOf(b));
        if (c != 0) return c;
        final ea = a.anime.externalMeta?.averageNormalizedScore ?? -1;
        final eb = b.anime.externalMeta?.averageNormalizedScore ?? -1;
        final e = eb.compareTo(ea);
        if (e != 0) return e;
        final t = b.anime.createdAt.compareTo(a.anime.createdAt);
        return t != 0 ? t : a.anime.id.compareTo(b.anime.id);
      });
    } else {
      out.sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.anime.id.compareTo(b.anime.id);
      });
    }
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Purpose: Say whether a record can be recommended at all.
  /// Inputs: `anime`, `nowJst`.
  /// Returns: `bool` — not started, or being watched with aired unwatched
  /// episodes.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _eligible(Anime anime, DateTime nowJst) =>
      switch (anime.viewingStatus) {
        AnimeViewingStatus.notStarted => true,
        AnimeViewingStatus.watching => hasAiredUnwatched(anime, nowJst),
        _ => false,
      };

  /// Purpose: Pick the highest external score for a reason chip.
  /// Inputs: `anime`.
  /// Returns: `ExternalScoreReason?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static ExternalScoreReason? _bestExternal(Anime anime) {
    ExternalScoreReason? best;
    for (final r
        in anime.externalMeta?.ratings ?? const <AnimeExternalRating>[]) {
      final v = r.normalizedScore;
      if (v != null && (best == null || v > best.score)) {
        best = ExternalScoreReason(r.source, v);
      }
    }
    return best;
  }
}
