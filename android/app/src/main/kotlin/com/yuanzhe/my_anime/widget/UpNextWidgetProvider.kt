package com.yuanzhe.my_anime.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.yuanzhe.my_anime.R

/**
 * 2x2 "Up next" widget: today's update count, the aired episodes left to
 * watch, and the first anime in the watch queue (or the next airing one).
 */
class UpNextWidgetProvider : AppWidgetProvider() {

    /**
     * Purpose: Redraw every instance from the stored snapshot.
     * Inputs: `context`, `appWidgetManager`, `appWidgetIds`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: Called on add and by the system update period; the snapshot is
     * re-evaluated at the current time, so newly aired episodes appear.
     */
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val state = UpNextState.load(WidgetStore.prefs(context))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, state, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    /**
     * Purpose: Redraw one instance after the user resizes it.
     * Inputs: `context`, `appWidgetManager`, `appWidgetId`, `newOptions`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: The second queue row appears only when the widget is tall enough.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val state = UpNextState.load(WidgetStore.prefs(context))
        appWidgetManager.updateAppWidget(appWidgetId, render(context, state, newOptions))
    }

    companion object {
        /** Minimum widget height, in dp, that fits two queue rows. */
        private const val TWO_ROW_MIN_HEIGHT_DP = 150

        /**
         * Purpose: Build the 2x2 RemoteViews for a state.
         * Inputs: `context`, `state`, `options` — the instance's size options.
         * Returns: `RemoteViews`.
         * Side effects: None.
         * Notes: Caught up shows the label instead of a zero; with an empty
         * queue the row shows the next airing episode instead.
         */
        fun render(context: Context, state: UpNextState, options: Bundle?): RemoteViews {
            val now = System.currentTimeMillis()
            val views = RemoteViews(context.packageName, R.layout.widget_up_next)
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            views.setTextViewText(R.id.app_name, state.label("appName"))
            views.setTextViewText(R.id.today_pill, "${state.label("today")} ${state.todayCount}")

            if (state.toWatch > 0) {
                views.setTextViewTextSize(R.id.count, TypedValue.COMPLEX_UNIT_SP, 36f)
                views.setTextViewText(R.id.count, state.toWatch.toString())
                views.setTextViewText(
                    R.id.count_label,
                    "${state.label("toWatch")} · ${state.series(state.queue.size)}",
                )
            } else {
                views.setTextViewTextSize(R.id.count, TypedValue.COMPLEX_UNIT_SP, 20f)
                views.setTextViewText(R.id.count, state.label("caughtUp"))
                views.setTextViewText(
                    R.id.count_label,
                    if (state.nextUp == null) state.label("noUpdates") else state.label("next"),
                )
            }

            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
            val rowCount = if (minHeight == 0 || minHeight >= TWO_ROW_MIN_HEIGHT_DP) 2 else 1
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

        /**
         * Purpose: Build the tap action that opens the app.
         * Inputs: `context`.
         * Returns: An immutable `PendingIntent` for the launcher activity.
         * Side effects: None.
         * Notes: Shared by both widget sizes.
         */
        fun launchIntent(context: Context): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent()
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
