package com.yuanzhe.my_anime.widget

import android.content.Context
import android.os.Bundle
import android.widget.RemoteViews
import com.yuanzhe.my_anime.R
import com.yuanzhe.myapps_widget.EnvelopeWidgetProvider
import com.yuanzhe.myapps_widget.WidgetLaunch
import com.yuanzhe.myapps_widget.setScaledTextSize

/** 2x1 strip widget: a tonal to-watch count tile and the next anime to watch. */
class UpNextStripWidgetProvider : EnvelopeWidgetProvider() {

    /**
     * Purpose: Draw one instance from the stored envelope.
     * Inputs: `context`, `appWidgetId`, `options` (unused; the strip has one layout).
     * Returns: `RemoteViews`.
     * Side effects: Reads the envelope store.
     * Notes: Called by the shared base on add, update period, resize and publish.
     */
    override fun render(context: Context, appWidgetId: Int, options: Bundle?): RemoteViews =
        render(context, UpNextState.load(context))

    companion object {
        /**
         * Purpose: Build the strip RemoteViews for a state.
         * Inputs: `context`, `state`.
         * Returns: `RemoteViews`.
         * Side effects: None.
         * Notes: Line 1 is the first queued title (or "caught up"); line 2 is
         * its episode plus today's update count, or the next airing episode.
         * Text sizes are the layout's, times the snapshot's text scale.
         */
        fun render(context: Context, state: UpNextState): RemoteViews {
            val now = System.currentTimeMillis()
            val views = RemoteViews(context.packageName, R.layout.widget_up_next_strip)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetLaunch.pendingIntent(context))
            views.setScaledTextSize(R.id.count, 18f, state.textScale)
            views.setScaledTextSize(R.id.line1, 14f, state.textScale)
            views.setScaledTextSize(R.id.line2, 12f, state.textScale)
            views.setTextViewText(R.id.count, if (state.toWatch > 0) state.toWatch.toString() else "✓")
            val today = "${state.label("today")} ${state.todayCount}"
            val first = state.queue.firstOrNull()
            val next = state.nextUp
            when {
                first != null -> {
                    views.setTextViewText(R.id.line1, first.title)
                    views.setTextViewText(R.id.line2, "${state.episode(first.episode)} · $today")
                }
                next != null -> {
                    views.setTextViewText(R.id.line1, state.label("caughtUp"))
                    views.setTextViewText(
                        R.id.line2,
                        "${state.label("next")} ${state.airTime(next.airAt, now)} · ${next.title}",
                    )
                }
                else -> {
                    views.setTextViewText(R.id.line1, state.label("caughtUp"))
                    views.setTextViewText(R.id.line2, state.label("noUpdates"))
                }
            }
            return views
        }
    }
}
