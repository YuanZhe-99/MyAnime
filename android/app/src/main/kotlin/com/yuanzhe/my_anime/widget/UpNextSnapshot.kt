package com.yuanzhe.my_anime.widget

import android.content.Context
import com.yuanzhe.myapps_widget.EnvelopeStore
import com.yuanzhe.myapps_widget.WidgetEnvelopeStatus
import com.yuanzhe.myapps_widget.WidgetTextScale
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
 * The widget state at one instant, derived from the MyApps-Widget envelope of
 * kind `myanime.upNext` that `lib/shared/services/home_widget_service.dart`
 * publishes. The payload is documented in
 * `doc/en-us/features/home-screen-widgets.md`.
 */
data class UpNextState(
    val toWatch: Int,
    val queue: List<WidgetEpisode>,
    val todayCount: Int,
    val nextUp: WidgetEpisode?,
    val labels: Map<String, String>,
    val zone: ZoneId,
    val textScale: Float = 1f,
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
        /** Envelope kind; matches `HomeWidgetService.kind`. */
        const val KIND = "myanime.upNext"

        /** Pre-1.9.5 store, read only until the app publishes its first envelope. */
        private const val LEGACY_PREFERENCES = "MyAnimeWidget"
        private const val LEGACY_SNAPSHOT_KEY = "myanime_widget_snapshot"

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
         * Purpose: Read the stored envelope and evaluate it at `now`.
         * Inputs: `context`; `now` — epoch milliseconds.
         * Returns: The state, or an empty state when no readable envelope exists.
         * Side effects: Reads `EnvelopeStore` and, before the first 1.9.5 publish, the legacy preferences.
         * Notes: A missing envelope falls back to the pre-1.9.5 `MyAnimeWidget` snapshot, so widgets
         * placed before the update keep their content until the app runs. Invalid or too-new envelopes
         * read as empty.
         */
        fun load(context: Context, now: Long = System.currentTimeMillis()): UpNextState {
            val read = EnvelopeStore.read(context, KIND)
            return try {
                when (read.status) {
                    WidgetEnvelopeStatus.OK -> {
                        val e = read.envelope!!
                        evaluate(e.payload, e.generatedAt, e.textScale, now)
                    }
                    WidgetEnvelopeStatus.MISSING -> loadLegacy(context, now)
                    else -> EMPTY
                }
            } catch (e: Exception) {
                EMPTY
            }
        }

        /**
         * Purpose: Evaluate the pre-1.9.5 snapshot, whose fields sat at the top level.
         * Inputs: `context`, `now`.
         * Returns: The state, or an empty state.
         * Side effects: Reads the legacy preferences.
         * Notes: Remove once 1.9.4 is no longer in the field.
         */
        private fun loadLegacy(context: Context, now: Long): UpNextState {
            val raw = context.getSharedPreferences(LEGACY_PREFERENCES, Context.MODE_PRIVATE)
                .getString(LEGACY_SNAPSHOT_KEY, null) ?: return EMPTY
            val json = JSONObject(raw)
            return evaluate(
                json,
                json.optLong("generatedAt"),
                WidgetTextScale.clamp(json.optDouble("textScale", 1.0)),
                now,
            )
        }

        /**
         * Purpose: Evaluate a payload at an instant.
         * Inputs: `json` — the envelope payload; `generatedAt` and `now` — epoch milliseconds;
         * `textScale` — already clamped.
         * Returns: `UpNextState`.
         * Side effects: None.
         * Notes: Mirrors `HomeWidgetService.buildSnapshot`: episodes that aired
         * after `generatedAt` join the to-watch count and queue, so the widget
         * stays right between app launches within the snapshot's lookahead.
         */
        fun evaluate(json: JSONObject, generatedAt: Long, textScale: Float, now: Long): UpNextState {
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
            return UpNextState(toWatch, queue, todayCount, nextUp, labels, zone, textScale)
        }
    }
}
