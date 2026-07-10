package `in`.filamentai.cointoss

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlin.random.Random

/**
 * Home-screen coin-toss widget. Tapping it flips a fair coin right on the
 * launcher (no app launch needed) and shows HEADS / TAILS. Pure native
 * RemoteViews so it works without the Flutter engine running.
 */
class CoinWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOSS = "in.filamentai.cointoss.ACTION_TOSS"

        fun render(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            result: String?,
        ) {
            val views = RemoteViews(context.packageName, R.layout.coin_widget)
            when (result) {
                "HEADS" -> {
                    views.setImageViewResource(R.id.coin_image, R.drawable.coin_heads)
                    views.setTextViewText(R.id.result_text, "HEADS")
                }
                "TAILS" -> {
                    views.setImageViewResource(R.id.coin_image, R.drawable.coin_tails)
                    views.setTextViewText(R.id.result_text, "TAILS")
                }
                else -> {
                    views.setImageViewResource(R.id.coin_image, R.drawable.coin_heads)
                    views.setTextViewText(R.id.result_text, "TAP TO TOSS")
                }
            }

            // Tapping the widget re-broadcasts a toss for this widget id.
            val intent = Intent(context, CoinWidgetProvider::class.java).apply {
                action = ACTION_TOSS
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            }
            val flags =
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pending = PendingIntent.getBroadcast(context, id, intent, flags)
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            manager.updateAppWidget(id, views)
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, manager, id, null)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOSS) {
            val id = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val result = if (Random.nextBoolean()) "HEADS" else "TAILS"
                render(context, AppWidgetManager.getInstance(context), id, result)
            }
        }
    }
}
