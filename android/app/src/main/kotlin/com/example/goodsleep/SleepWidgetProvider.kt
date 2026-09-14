package com.example.goodsleep

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class SleepWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sleep_widget)
            val data = HomeWidgetPlugin.getData(context)

            val babyName = data.getString("babyName", "Bebek") ?: "Bebek"
            val isSleeping = data.getBoolean("isSleeping", false)
            val duration = data.getString("sleepDuration", "") ?: ""

            views.setTextViewText(R.id.widget_baby_name, babyName)
            views.setTextViewText(
                R.id.widget_status,
                if (isSleeping) "Uyuyor • $duration" else "Uyanık"
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
