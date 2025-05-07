package meditofoundation.medito

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

class StatsWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "StatsWidget"
        private const val FLUTTER_SHARED_PREFS = "FlutterSharedPreferences"
        
        fun updateWidgetData(context: Context, data: Map<String, Any>) {
            Log.d(TAG, "Updating widget data: $data")
            
            try {
                // Get current streak
                val currentStreak = (data["current_streak"] as? Number)?.toInt() ?: 0
                
                // Get longest streak
                val longestStreak = (data["best_streak"] as? Number)?.toInt() ?: 0
                
                // Get minutes meditated
                val minutesMeditated = ((data["total_time"] as? Number)?.toInt() ?: 0) / 60
                
                // Get total sessions
                val totalSessions = (data["total_sessions"] as? Number)?.toInt() ?: 0
  
                // Update all instances of the widget
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    context.getComponentName(StatsWidgetReceiver::class.java)
                )
                
                updateAppWidgets(
                    context,
                    appWidgetManager,
                    appWidgetIds,
                    data
                )
                
                Log.d(TAG, "Successfully updated ${appWidgetIds.size} widgets")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget data", e)
            }
        }
        
        fun extractDataFromFlutter(context: Context): Map<String, Any> {
            val data = mutableMapOf<String, Any>()
            try {
                val homeWidgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                // Log all keys and values for debugging
                val allPrefs = homeWidgetPrefs.all
                Log.d(TAG, "All HomeWidget preferences keys: ${allPrefs.keys}")
                for ((key, value) in allPrefs) {
                    Log.d(TAG, "HomeWidgetPreferences: $key = $value")
                }
                
                // Get data from HomeWidget's SharedPreferences with the standard keys used by HomeWidget
                val streakCurrent = getIntValue(homeWidgetPrefs, "current_streak", 0)
                val streakLongest = getIntValue(homeWidgetPrefs, "best_streak", 0)
                val totalTime = getIntValue(homeWidgetPrefs, "total_time", 0)
                val minutesMeditated = totalTime / 60
                val totalSessions = getIntValue(homeWidgetPrefs, "total_sessions", 0)
                
                // Add data to the map using the same keys as in updateWidgetData
                data["current_streak"] = streakCurrent
                data["best_streak"] = streakLongest
                data["total_time"] = totalTime
                data["total_sessions"] = totalSessions

                // Extract calendar streak 7 days JSON
                val streak7daysJson = getStringValue(homeWidgetPrefs, "calendar_streak_7days", "")
                if (streak7daysJson.isNotEmpty()) {
                    data["calendar_streak_7days"] = streak7daysJson
                }
                
                // Extract subscription status
                val hasActiveSubscriptionRaw = homeWidgetPrefs.all["has_active_subscription"]
                Log.d(TAG, "Raw value for 'has_active_subscription' from prefs.all: $hasActiveSubscriptionRaw, type: ${hasActiveSubscriptionRaw?.javaClass?.name}")

                val isSubscriber = when (hasActiveSubscriptionRaw) {
                    is Boolean -> {
                        Log.d(TAG, "Interpreting 'has_active_subscription' as Boolean: $hasActiveSubscriptionRaw")
                        hasActiveSubscriptionRaw
                    }
                    is String -> {
                        Log.d(TAG, "Interpreting 'has_active_subscription' as String: '$hasActiveSubscriptionRaw'")
                        // Handles "true" (any case) or "1" as true. Other strings parse via String.toBoolean()
                        if (hasActiveSubscriptionRaw.equals("true", ignoreCase = true) || hasActiveSubscriptionRaw == "1") {
                            true
                        } else {
                            hasActiveSubscriptionRaw.toBoolean() // Standard Kotlin string to boolean
                        }
                    }
                    is Int -> {
                        Log.d(TAG, "Interpreting 'has_active_subscription' as Int: $hasActiveSubscriptionRaw")
                        hasActiveSubscriptionRaw != 0
                    }
                    is Long -> {
                        Log.d(TAG, "Interpreting 'has_active_subscription' as Long: $hasActiveSubscriptionRaw")
                        hasActiveSubscriptionRaw != 0L
                    }
                    is Double -> {
                        Log.d(TAG, "Interpreting 'has_active_subscription' as Double: $hasActiveSubscriptionRaw")
                        hasActiveSubscriptionRaw != 0.0
                    }
                    else -> {
                        Log.w(TAG, "Unknown type for 'has_active_subscription': ${hasActiveSubscriptionRaw?.javaClass?.name}, value: $hasActiveSubscriptionRaw. Defaulting to false.")
                        false
                    }
                }
                data["has_active_subscription"] = isSubscriber
                
                Log.d(TAG, "Extracted data from HomeWidget prefs: $data")
            } catch (e: Exception) {
                Log.e(TAG, "Error extracting data from HomeWidget prefs", e)
            }
            
            return data
        }
        
        private fun getIntValue(prefs: SharedPreferences, key: String, defaultValue: Int): Int {
            return try {
                val value = prefs.all[key]
                when (value) {
                    is Int -> value
                    is String -> value.toIntOrNull() ?: defaultValue
                    is Long -> value.toInt()
                    is Float -> value.toInt()
                    else -> defaultValue
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error getting int value for key $key", e)
                defaultValue
            }
        }
        
        private fun getStringValue(prefs: SharedPreferences, key: String, defaultValue: String): String {
            return try {
                prefs.getString(key, defaultValue) ?: defaultValue
            } catch (e: Exception) {
                Log.e(TAG, "Error getting string value for key $key", e)
                defaultValue
            }
        }
        
        fun updateAppWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            data: Map<String, Any>
        ) {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(
                    context,
                    appWidgetManager,
                    appWidgetId,
                    data
                )
            }
        }
        
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            data: Map<String, Any>
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.stats_widget_layout)

                // Get widget width options. This is needed for calendar and potentially other dynamic layout adjustments.
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                // Use a default of 0 if not found, though it's usually present for resizable widgets.
                val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

                val streak7daysJson = data["calendar_streak_7days"] as? String
                if (streak7daysJson != null) {
                    try {
                        val streakArray = JSONArray(streak7daysJson)

                        // Get widget width and set row height
                        val density = context.resources.displayMetrics.density
                        val minWidthPx = (minWidthDp * density).toInt()

                        // Add 8dp side padding (in px)
                        val sidePaddingPx = (8 * density)
                        val availableWidth = minWidthPx - 2 * sidePaddingPx

                        val circleDiameter = availableWidth / 7f * 0.7f
                        val circleRadius = circleDiameter / 2f
                        val totalCirclesWidth = circleDiameter * 7
                        val remainingWidth = (availableWidth - totalCirclesWidth).coerceAtLeast(0f)
                        val gap = if (7 > 1) remainingWidth / 6f * 0.6f else 0f // reduce gap between circles

                        val startX = sidePaddingPx + (availableWidth - (totalCirclesWidth + gap * 6)) / 2f + circleRadius // centre the row with side padding

                        val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
                        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = Color.WHITE
                            textAlign = Paint.Align.CENTER
                            textSize = minWidthPx / 7f * 0.28f
                            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
                        }

                        // Calculate label height using font metrics
                        val fontMetrics = labelPaint.fontMetrics
                        val labelHeight = fontMetrics.descent - fontMetrics.ascent
                        val labelToCircleGap = circleDiameter * 0.18f
                        val topPadding = circleDiameter * 0.12f
                        val bottomPadding = circleDiameter * 0.12f
                        val rowHeightPx = (topPadding + labelHeight + labelToCircleGap + circleDiameter + bottomPadding).toInt()

                        // Prepare bitmap and canvas with new height
                        val bitmap = Bitmap.createBitmap(minWidthPx, rowHeightPx, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bitmap)
                        canvas.drawColor(Color.TRANSPARENT)

                        // Positioning
                        val labelY = topPadding - fontMetrics.ascent
                        val cy = topPadding + labelHeight + labelToCircleGap + circleRadius

                        // Get current day of week (1=Monday, 7=Sunday)
                        val calendar = java.util.Calendar.getInstance()
                        val todayIdx = (calendar.get(java.util.Calendar.DAY_OF_WEEK) + 5) % 7 // 0=Monday, 6=Sunday
                        val dayLabels = arrayOf("M", "T", "W", "T", "F", "S", "S")

                        // Rotate labels so the right-most is today
                        val rotatedLabels = Array(7) { i -> dayLabels[(i + 7 - (6 - todayIdx)) % 7] }

                        // If streakArray is not already ordered oldest to newest, rotate it as well
                        // (Assume streakArray[6] is today, [0] is 6 days ago)
                        for (i in 0 until 7) {
                            val cx = startX + i * (circleDiameter + gap)
                            val checked = streakArray.optBoolean(i, false)
                            circlePaint.color = if (checked) Color.parseColor("#FFFFFFFF") else Color.parseColor("#44FFFFFF")
                            canvas.drawCircle(cx, cy, circleRadius, circlePaint)
                            
                            // Draw checkmark if checked
                            if (checked) {
                                val checkmarkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                    color = Color.parseColor("#917DF0")
                                    style = Paint.Style.STROKE
                                    strokeWidth = circleDiameter * 0.13f
                                    strokeCap = Paint.Cap.ROUND
                                    strokeJoin = Paint.Join.ROUND
                                }
                                val checkStartX = cx - circleRadius * 0.5f
                                val checkStartY = cy + circleRadius * 0.05f
                                val checkMidX = cx - circleRadius * 0.1f
                                val checkMidY = cy + circleRadius * 0.45f
                                val checkEndX = cx + circleRadius * 0.5f
                                val checkEndY = cy - circleRadius * 0.35f
                                val path = android.graphics.Path().apply {
                                    moveTo(checkStartX, checkStartY)
                                    lineTo(checkMidX, checkMidY)
                                    lineTo(checkEndX, checkEndY)
                                }
                                canvas.drawPath(path, checkmarkPaint)
                            }

                            // Set label alpha: 255 if checked, 100 if not
                            labelPaint.alpha = if (checked) 255 else 100
                            canvas.drawText(rotatedLabels[i], cx, labelY, labelPaint)
                        }

                        views.setImageViewBitmap(R.id.streak_calendar_bitmap, bitmap)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing calendar_streak_7days or setting labels", e)
                    }
                }

                // Show overlay if user is NOT a subscriber
                val isSubscriber = data["has_active_subscription"] as? Boolean ?: false
                Log.d(TAG, "Subscriber status for overlay: $isSubscriber")
                if (!isSubscriber) {
                    views.setViewVisibility(R.id.subscriber_overlay, View.VISIBLE)
                    Log.d(TAG, "Subscriber overlay VISIBLE (user IS NOT a subscriber)")

                    // Adjust text size for the "supporters" message based on widget width.
                    val subscriberMessageTextViewId = R.id.subscriber_overlay_text

                    // Define text sizes and threshold
                    val defaultTextSizeSp = 12f
                    val smallTextSizeSp = 10f
                    val widthThresholdDp = 150

                    if (minWidthDp > 0 && minWidthDp < widthThresholdDp) {
                        views.setTextViewTextSize(subscriberMessageTextViewId, TypedValue.COMPLEX_UNIT_SP, smallTextSizeSp)
                        Log.d(TAG, "Using small text size (${smallTextSizeSp}sp) for subscriber message. Widget width: ${minWidthDp}dp")
                    } else {
                        views.setTextViewTextSize(subscriberMessageTextViewId, TypedValue.COMPLEX_UNIT_SP, defaultTextSizeSp)
                        Log.d(TAG, "Using default text size (${defaultTextSizeSp}sp) for subscriber message. Widget width: ${minWidthDp}dp")
                    }

                } else {
                    views.setViewVisibility(R.id.subscriber_overlay, View.GONE)
                    Log.d(TAG, "Subscriber overlay GONE (user IS a subscriber)")
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "Widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget $appWidgetId", e)
            }
        }
        
        private fun Context.getComponentName(cls: Class<*>) = android.content.ComponentName(this, cls)
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Get data from Flutter shared preferences
        val data = extractDataFromFlutter(context)
        if (data.isNotEmpty()) {
            // Update widget with data
            updateAppWidgets(context, appWidgetManager, appWidgetIds, data)
        }
    }
}

class StatsWidgetReceiver : AppWidgetProvider() {
    companion object {
        private const val TAG = "StatsWidgetReceiver"
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        
        try {
            // Get data from Flutter shared preferences
            val flutterData = StatsWidget.extractDataFromFlutter(context)
            if (flutterData.isNotEmpty()) {
                StatsWidget.updateAppWidgets(
                    context,
                    appWidgetManager,
                    appWidgetIds,
                    flutterData
                )
            } else {
                Log.d(TAG, "No data found in Flutter shared preferences")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget from receiver", e)
        }
    }
}