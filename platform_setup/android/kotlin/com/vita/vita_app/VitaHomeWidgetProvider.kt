package com.vita.vita_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.vita.vita_app.R

class VitaHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.vita_home_widget).apply {
                setTextViewText(R.id.vita_widget_temperature, widgetData.getString("temperature", "-- °C"))
                setTextViewText(R.id.vita_widget_heart, widgetData.getString("heartRate", "-- bpm"))
                setTextViewText(R.id.vita_widget_spo2, widgetData.getString("spo2", "-- %"))
                val connected = widgetData.getBoolean("connected", false)
                setTextViewText(R.id.vita_widget_status, widgetData.getString("dataStatus", if (connected) "Bluetooth conectado" else "Dados demonstrativos · sem dispositivo"))
                setTextViewText(R.id.vita_widget_updated, "Atualizado: ${widgetData.getString("updatedAt", "--")}")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
