package com.yuanzhe.my_anime.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences

/** Storage and redraw entry point shared by the Flutter channel and the widget providers. */
object WidgetStore {
    private const val PREFERENCES = "MyAnimeWidget"

    /**
     * Purpose: Open the private preferences that hold the widget snapshot.
     * Inputs: `context`.
     * Returns: `SharedPreferences`.
     * Side effects: None.
     * Notes: Device-local; never synced or backed up by the app.
     */
    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    /**
     * Purpose: Store a new snapshot from Flutter and redraw every widget instance.
     * Inputs: `context`, `snapshot` — the JSON string from `HomeWidgetService`.
     * Returns: None.
     * Side effects: Writes preferences and pushes RemoteViews to the launcher.
     * Notes: Called from `MainActivity`'s `home_widget` method channel.
     */
    fun push(context: Context, snapshot: String) {
        prefs(context).edit().putString(UpNextState.SNAPSHOT_KEY, snapshot).apply()
        redrawAll(context)
    }

    /**
     * Purpose: Redraw every placed instance of both widget sizes.
     * Inputs: `context`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: No-op when no widget is placed.
     */
    fun redrawAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val state = UpNextState.load(prefs(context))
        for (id in manager.getAppWidgetIds(ComponentName(context, UpNextWidgetProvider::class.java))) {
            manager.updateAppWidget(id, UpNextWidgetProvider.render(context, state, manager.getAppWidgetOptions(id)))
        }
        val strip = UpNextStripWidgetProvider.render(context, state)
        for (id in manager.getAppWidgetIds(ComponentName(context, UpNextStripWidgetProvider::class.java))) {
            manager.updateAppWidget(id, strip)
        }
    }
}
