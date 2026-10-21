package com.shiaai.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlin.random.Random

/** A genuinely useful Android launcher widget; refreshes on the platform's
 * hourly AppWidget schedule and can also be advanced with its refresh button.
 *
 * Adjustable by design: the widget is freely resizable (see
 * `moment_widget_info.xml`) and picks one of three layouts — compact,
 * standard, large — from the size the launcher actually gives it, both
 * when it is placed and every time the reader drags it to a new size.
 * All three sit on the same layered 3D slab (drop shadow, lit gold rim,
 * enamel face, inner groove, gloss sweep) drawn in
 * `moment_widget_background.xml`, with the refresh control as a brass orb. */
class MomentWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateOne(context, manager, it, hourly = true) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: android.os.Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, manager, id, newOptions)
        updateOne(context, manager, id, hourly = true)
    }

    /** Which of the three layouts fits the size [id] currently has. */
    private fun layoutFor(manager: AppWidgetManager, id: Int): Int {
        val options = manager.getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return when {
            width in 1..189 || height in 1..99 -> R.layout.moment_widget_compact
            width >= 300 && height >= 190 -> R.layout.moment_widget_large
            else -> R.layout.moment_widget
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_REFRESH) return
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, MomentWidgetProvider::class.java))
        ids.forEach { updateOne(context, manager, it, hourly = false) }
    }

    private fun updateOne(context: Context, manager: AppWidgetManager, id: Int, hourly: Boolean) {
        val views = RemoteViews(context.packageName, layoutFor(manager, id))
        val seed = if (hourly) System.currentTimeMillis() / HOUR_MS + id * 31L else System.nanoTime()
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val key = "quote_$id"
        val previous = prefs.getInt(key, -1)
        var selected = Random(seed.toInt()).nextInt(moments.size)
        if (selected == previous) selected = (selected + 1) % moments.size
        prefs.edit().putInt(key, selected).apply()
        val quote = moments[selected]
        views.setTextViewText(R.id.moment_text, quote.text)
        views.setTextViewText(R.id.moment_reference, quote.reference)

        val refreshIntent = Intent(context, MomentWidgetProvider::class.java).apply { action = ACTION_REFRESH }
        views.setOnClickPendingIntent(
            R.id.moment_refresh,
            PendingIntent.getBroadcast(context, id, refreshIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        )
        val openIntent = Intent(context, MainActivity::class.java)
        views.setOnClickPendingIntent(
            R.id.moment_root,
            PendingIntent.getActivity(context, id + 1000, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        )
        manager.updateAppWidget(id, views)
    }

    private data class Moment(val text: String, val reference: String)

    companion object {
        private const val ACTION_REFRESH = "com.shiaai.app.ACTION_REFRESH_MOMENT"
        private const val PREFS_NAME = "moment_widget"
        private const val HOUR_MS = 60L * 60L * 1000L

        // Carefully attributed selections from the Quran and Nahj al-Balagha.
        // The launcher widget is self-contained and remains useful offline.
        private val moments = listOf(
            Moment("بے شک اللہ صبر کرنے والوں کے ساتھ ہے۔", "قرآنِ کریم — البقرہ ۲:۱۵۳"),
            Moment("اور تمہارا رب فرماتا ہے: مجھ سے دعا کرو، میں قبول کروں گا۔", "قرآنِ کریم — غافر ۴۰:۶۰"),
            Moment("اللہ کے ذکر سے دل اطمینان پاتے ہیں۔", "قرآنِ کریم — الرعد ۱۳:۲۸"),
            Moment("نیکی اور تقویٰ کے کاموں میں ایک دوسرے کی مدد کرو۔", "قرآنِ کریم — المائدہ ۵:۲"),
            Moment("اور جو اللہ پر بھروسا کرے تو وہ اس کے لیے کافی ہے۔", "قرآنِ کریم — الطلاق ۶۵:۳"),
            Moment("بے شک مشکل کے ساتھ آسانی ہے۔", "قرآنِ کریم — الشرح ۹۴:۶"),
            Moment("اپنے نفس کا محاسبہ کرو، اس سے پہلے کہ تمہارا محاسبہ کیا جائے۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار"),
            Moment("لوگوں سے ایسا میل جول رکھو کہ تم نہ رہو تو وہ تمہیں یاد کریں۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار"),
            Moment("قناعت ایسا سرمایہ ہے جو کبھی ختم نہیں ہوتا۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار"),
            Moment("ہر شخص کی قدر اس کے اچھے کام کے مطابق ہے۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار"),
            Moment("آدمی اپنی زبان کے نیچے پوشیدہ ہے۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار"),
            Moment("دوست وہ ہے جو تمہیں تمہاری غلطی سے آگاہ کرے۔", "فرمانِ امیرالمؤمنینؑ — نہج البلاغہ، کلماتِ قصار")
        )
    }
}
