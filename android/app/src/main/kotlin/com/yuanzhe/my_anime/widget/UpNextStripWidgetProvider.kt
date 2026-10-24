package com.yuanzhe.my_anime.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.TypedValue
import android.widget.RemoteViews
import com.yuanzhe.my_anime.R

/** 2x1 strip widget: a tonal to-watch count tile and the next anime to watch. */
class UpNextStripWidgetProvider : AppWidgetProvider() {

    /**
     * Purpose: Redraw every instance from the stored snapshot.
     * Inputs: `context`, `appWidgetManager`, `appWidgetIds`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: Called on add and by the system update period.
     */
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = render(context, UpNextState.load(WidgetStore.prefs(context)))
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

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
            views.setOnClickPendingIntent(R.id.widget_root, UpNextWidgetProvider.launchIntent(context))
            views.setTextViewTextSize(R.id.count, TypedValue.COMPLEX_UNIT_SP, state.sp(18f))
            views.setTextViewTextSize(R.id.line1, TypedValue.COMPLEX_UNIT_SP, state.sp(14f))
            views.setTextViewTextSize(R.id.line2, TypedValue.COMPLEX_UNIT_SP, state.sp(12f))
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
