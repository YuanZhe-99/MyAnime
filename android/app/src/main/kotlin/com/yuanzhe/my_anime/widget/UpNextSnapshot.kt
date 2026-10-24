package com.yuanzhe.my_anime.widget

import android.content.SharedPreferences
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** One episode entry of the Flutter-written widget snapshot. */
data class WidgetEpisode(
    val animeId: String,
    val title: String,
    val episode: Int,
    val airAt: Long,
    val watched: Boolean,
)

/**
 * The widget state at one instant, derived from the snapshot that
 * `lib/shared/services/home_widget_service.dart` writes. The format is
 * documented in `doc/en-us/features/home-screen-widgets.md`.
 */
data class UpNextState(
    val toWatch: Int,
    val queue: List<WidgetEpisode>,
    val todayCount: Int,
    val nextUp: WidgetEpisode?,
    val labels: Map<String, String>,
    val zone: ZoneId,
) {
    /**
     * Purpose: Return a snapshot label, falling back to English.
     * Inputs: `key` — a key of the snapshot's `labels` object.
     * Returns: The label text.
     * Side effects: None.
     * Notes: Fallbacks cover a widget drawn before the app wrote a snapshot.
     */
    fun label(key: String): String = labels[key] ?: FALLBACK_LABELS[key] ?: key

    /**
     * Purpose: Format an episode number with the localized template.
     * Inputs: `number`.
     * Returns: For example "EP 7" or "第7集".
     * Side effects: None.
     * Notes: None.
     */
    fun episode(number: Int): String = label("episode").replace("{n}", number.toString())

    /**
     * Purpose: Format a series count with the localized template.
     * Inputs: `count`.
     * Returns: For example "3 series" or "3 部".
     * Side effects: None.
     * Notes: None.
     */
    fun series(count: Int): String = label("series").replace("{n}", count.toString())

    /**
     * Purpose: Format an air time in the snapshot's calendar zone.
     * Inputs: `airAt` and `now`, epoch milliseconds.
     * Returns: "HH:mm" for today, otherwise a short weekday plus "HH:mm".
     * Side effects: None.
     * Notes: Uses the device locale for the weekday name.
     */
    fun airTime(airAt: Long, now: Long): String {
        val at = Instant.ofEpochMilli(airAt).atZone(zone)
        val sameDay = at.toLocalDate() == Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val pattern = if (sameDay) "HH:mm" else "EEE HH:mm"
        return at.format(DateTimeFormatter.ofPattern(pattern, Locale.getDefault()))
    }

    companion object {
        /** Key of the snapshot JSON in `WidgetStore`'s preferences. */
        const val SNAPSHOT_KEY = "myanime_widget_snapshot"

        private val FALLBACK_LABELS = mapOf(
            "appName" to "MyAnime",
            "toWatch" to "to watch",
            "today" to "Today",
            "caughtUp" to "All caught up",
            "noUpdates" to "Nothing airs today",
            "next" to "Next",
            "episode" to "EP {n}",
            "series" to "{n} series",
        )

        private val EMPTY = UpNextState(0, emptyList(), 0, null, emptyMap(), ZoneId.systemDefault())

        /**
         * Purpose: Parse the stored snapshot and evaluate it at `now`.
         * Inputs: `prefs` — `WidgetStore.prefs`; `now` — epoch milliseconds.
         * Returns: The state, or an empty state when no valid snapshot exists.
         * Side effects: None.
         * Notes: None.
         */
        fun load(prefs: SharedPreferences, now: Long = System.currentTimeMillis()): UpNextState {
            val raw = prefs.getString(SNAPSHOT_KEY, null) ?: return EMPTY
            return try {
                evaluate(JSONObject(raw), now)
            } catch (e: Exception) {
                EMPTY
            }
        }

        /**
         * Purpose: Evaluate a parsed snapshot at an instant.
         * Inputs: `json`, `now` epoch milliseconds.
         * Returns: `UpNextState`.
         * Side effects: None.
         * Notes: Mirrors `HomeWidgetService.buildSnapshot`: episodes that aired
         * after `generatedAt` join the to-watch count and queue, so the widget
         * stays right between app launches within the snapshot's lookahead.
         */
        fun evaluate(json: JSONObject, now: Long): UpNextState {
            val generatedAt = json.optLong("generatedAt")
            val zoneId = json.optString("timeZone")
            val zone = if (zoneId.isEmpty()) ZoneId.systemDefault() else ZoneId.of(zoneId)
            val labels = mutableMapOf<String, String>()
            json.optJSONObject("labels")?.let { o ->
                o.keys().forEach { labels[it] = o.optString(it) }
            }

            val array = json.optJSONArray("episodes")
            val episodes = (0 until (array?.length() ?: 0)).map { i ->
                val o = array!!.getJSONObject(i)
                WidgetEpisode(
                    o.optString("id"), o.optString("t"), o.optInt("e"),
                    o.optLong("at"), o.optBoolean("w"),
                )
            }.sortedBy { it.airAt }

            val newlyAired = episodes.count { !it.watched && it.airAt > generatedAt && it.airAt <= now }
            val toWatch = json.optInt("airedUnwatched") + newlyAired

            val seen = HashSet<String>()
            val queue = episodes.filter { !it.watched && it.airAt <= now && seen.add(it.animeId) }

            val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
            val todayCount = episodes.count {
                Instant.ofEpochMilli(it.airAt).atZone(zone).toLocalDate() == today
            }
            val nextUp = episodes.firstOrNull { !it.watched && it.airAt > now }
            return UpNextState(toWatch, queue, todayCount, nextUp, labels, zone)
        }
    }
}
