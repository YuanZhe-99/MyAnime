package com.yuanzhe.my_anime.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.yuanzhe.my_anime.R
import com.yuanzhe.myapps_widget.EnvelopeWidgetProvider
import com.yuanzhe.myapps_widget.WidgetLaunch
import com.yuanzhe.myapps_widget.setScaledTextSize

/**
 * 2x2 "Up next" widget: today's update count, the aired episodes left to
 * watch, and the first anime in the watch queue (or the next airing one).
 */
class UpNextWidgetProvider : EnvelopeWidgetProvider() {

    /**
     * Purpose: Draw one instance from the stored envelope.
     * Inputs: `context`, `appWidgetId`, `options` — the instance's size options.
     * Returns: `RemoteViews`.
     * Side effects: Reads the envelope store.
     * Notes: The shared base calls this on add, on the system update period, on
     * resize and after each publish; the payload is re-evaluated at the current
     * time, so newly aired episodes appear.
     */
    override fun render(context: Context, appWidgetId: Int, options: Bundle?): RemoteViews =
        render(context, UpNextState.load(context), options)

    companion object {
        /** Minimum widget height, in dp, that fits two queue rows at 100% text. */
        private const val TWO_ROW_MIN_HEIGHT_DP = 150

        /** Text views and their layout sizes in sp at 100%; `count` is sized per state. */
        private val SCALED_TEXT = listOf(
            R.id.app_name to 12f,
            R.id.today_pill to 11f,
            R.id.count_label to 12f,
            R.id.row1_title to 13f,
            R.id.row1_meta to 12f,
            R.id.row2_title to 13f,
            R.id.row2_meta to 12f,
        )

        /**
         * Purpose: Build the 2x2 RemoteViews for a state.
         * Inputs: `context`, `state`, `options` — the instance's size options.
         * Returns: `RemoteViews`.
         * Side effects: None.
         * Notes: Caught up shows the label instead of a zero; with an empty
         * queue the row shows the next airing episode instead. Text sizes and
         * the two-row height threshold grow with the snapshot's text scale.
         */
        fun render(context: Context, state: UpNextState, options: Bundle?): RemoteViews {
            val now = System.currentTimeMillis()
            val views = RemoteViews(context.packageName, R.layout.widget_up_next)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetLaunch.pendingIntent(context))
            for ((id, base) in SCALED_TEXT) {
                views.setScaledTextSize(id, base, state.textScale)
            }
            views.setTextViewText(R.id.app_name, state.label("appName"))
            views.setTextViewText(R.id.today_pill, "${state.label("today")} ${state.todayCount}")

            if (state.toWatch > 0) {
                views.setScaledTextSize(R.id.count, 36f, state.textScale)
                views.setTextViewText(R.id.count, state.toWatch.toString())
                views.setTextViewText(
                    R.id.count_label,
                    "${state.label("toWatch")} · ${state.series(state.queue.size)}",
                )
            } else {
                views.setScaledTextSize(R.id.count, 20f, state.textScale)
                views.setTextViewText(R.id.count, state.label("caughtUp"))
                views.setTextViewText(
                    R.id.count_label,
                    if (state.nextUp == null) state.label("noUpdates") else state.label("next"),
                )
            }

            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
            val twoRowHeight = TWO_ROW_MIN_HEIGHT_DP * state.textScale
            val rowCount = if (minHeight == 0 || minHeight >= twoRowHeight) 2 else 1
            val rows = if (state.queue.isNotEmpty()) {
                state.queue.take(rowCount).map { it.title to state.episode(it.episode) }
            } else {
                listOfNotNull(state.nextUp).map {
                    it.title to "${state.episode(it.episode)} · ${state.airTime(it.airAt, now)}"
                }
            }
            bindRow(views, R.id.row1, R.id.row1_title, R.id.row1_meta, rows.getOrNull(0))
            bindRow(views, R.id.row2, R.id.row2_title, R.id.row2_meta, rows.getOrNull(1))
            return views
        }

        /**
         * Purpose: Fill or hide one title/meta row.
         * Inputs: `views`, the row's view ids, and `row` (title to meta) or null.
         * Returns: None.
         * Side effects: Mutates `views`.
         * Notes: None.
         */
        private fun bindRow(
            views: RemoteViews,
            rowId: Int,
            titleId: Int,
            metaId: Int,
            row: Pair<String, String>?,
        ) {
            if (row == null) {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(titleId, row.first)
            views.setTextViewText(metaId, row.second)
        }
    }
}
