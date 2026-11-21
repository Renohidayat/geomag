package com.geomag.geomag

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class MagnetometerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_THERMAL_ALERT = "geomag_thermal_alert"
        const val CHANNEL_MAGNETIC_ALERT = "geomag_magnetic_alert"
    }

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var magnetometerEventChannel: EventChannel
    private lateinit var thermalEventChannel: EventChannel

    private var sensorManager: SensorManager? = null
    private var sensorEventListener: SensorEventListener? = null
    private var activeSensor: Sensor? = null
    private var isUncalibrated: Boolean = true
    private var targetDelayUs: Int = SensorManager.SENSOR_DELAY_FASTEST

    private var pressureSensor: Sensor? = null
    private var pressureListener: SensorEventListener? = null

    // Cache volatile untuk pembacaan O(1) di loop 50 Hz magnetometer
    @Volatile private var cachedBatteryTempC: Double = -1.0
    @Volatile private var cachedIsCharging: Boolean = false
    @Volatile private var cachedIsScreenOn: Boolean = true
    @Volatile private var cachedCurrentNowMa: Double? = null
    @Volatile private var cachedAmbientTempHardwareC: Double? = null
    @Volatile private var cachedPressureHpa: Double = -1.0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

        methodChannel = MethodChannel(binding.binaryMessenger, "com.geomag/magnetometer_method")
        methodChannel.setMethodCallHandler(this)

        magnetometerEventChannel = EventChannel(binding.binaryMessenger, "com.geomag/magnetometer_event")
        magnetometerEventChannel.setStreamHandler(MagnetometerStreamHandler())

        thermalEventChannel = EventChannel(binding.binaryMessenger, "com.geomag/thermal_event")
        thermalEventChannel.setStreamHandler(ThermalStreamHandler())

        // Inisialisasi awal nilai baterai sekali saja di background thread / startup
        refreshBatteryStateOnce()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMagnetometerListening()
        methodChannel.setMethodCallHandler(null)
        magnetometerEventChannel.setStreamHandler(null)
        thermalEventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSensorInfo" -> {
                val info = getSensorInfo()
                result.success(info)
            }
            "setTargetRate" -> {
                val rateHz = call.argument<Int>("rateHz") ?: 50
                targetDelayUs = if (rateHz > 0) 1_000_000 / rateHz else SensorManager.SENSOR_DELAY_FASTEST
                result.success(true)
            }
            "hasAmbientTemperatureSensor" -> {
                val sm = sensorManager
                val hasSensor = sm?.getDefaultSensor(Sensor.TYPE_AMBIENT_TEMPERATURE) != null
                result.success(hasSensor)
            }
            "getThermalSnapshot" -> {
                refreshBatteryStateOnce()
                result.success(buildThermalDataMap())
            }
            "initNotificationChannels" -> {
                initNotificationChannels()
                result.success(true)
            }
            "showNotification" -> {
                val id = call.argument<Int>("id") ?: 1001
                val channelId = call.argument<String>("channelId") ?: CHANNEL_THERMAL_ALERT
                val title = call.argument<String>("title") ?: "GeoMag Alert"
                val body = call.argument<String>("body") ?: ""
                val success = showNativeNotification(id, channelId, title, body)
                result.success(success)
            }
            "cancelNotification" -> {
                val id = call.argument<Int>("id") ?: 1001
                cancelNativeNotification(id)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun getSensorInfo(): Map<String, Any?> {
        val sm = sensorManager ?: return mapOf("available" to false)
        val uncal = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED)
        val cal = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        val sensor = uncal ?: cal

        return mapOf(
            "available" to (sensor != null),
            "isUncalibrated" to (uncal != null),
            "name" to sensor?.name,
            "vendor" to sensor?.vendor,
            "version" to sensor?.version,
            "resolution" to sensor?.resolution?.toDouble(),
            "maxRange" to sensor?.maximumRange?.toDouble(),
            "minDelay" to sensor?.minDelay,
            "maxDelay" to sensor?.maxDelay,
            "power" to sensor?.power?.toDouble()
        )
    }

    private fun refreshBatteryStateOnce() {
        try {
            val intentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, intentFilter)
            updateBatteryFromIntent(batteryStatus)
        } catch (_: Exception) {}
    }

    private fun updateBatteryFromIntent(intent: Intent?) {
        if (intent == null) return
        val temp = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
        if (temp > 0) {
            cachedBatteryTempC = temp / 10.0
        }
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        cachedIsCharging = (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL)
        updateCurrentNow()
        updateScreenState()
    }

    private fun updateCurrentNow() {
        try {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (bm != null) {
                val current = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                // Sebagian vendor melaporkan dalam mikroampere (µA), sebagian dalam mA.
                // Jika |current| > 10.000, ubah µA ke mA.
                if (current != Int.MIN_VALUE && current != 0) {
                    cachedCurrentNowMa = if (abs(current) > 10000) {
                        current / 1000.0
                    } else {
                        current.toDouble()
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun updateScreenState() {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            cachedIsScreenOn = pm?.isInteractive == true
        } catch (_: Exception) {
            cachedIsScreenOn = true
        }
    }

    private fun buildThermalDataMap(): Map<String, Any?> {
        val sm = sensorManager
        val hasAmbient = sm?.getDefaultSensor(Sensor.TYPE_AMBIENT_TEMPERATURE) != null
        return mapOf(
            "timestampNs" to System.nanoTime(),
            "batteryTempC" to cachedBatteryTempC,
            "isCharging" to cachedIsCharging,
            "isScreenOn" to cachedIsScreenOn,
            "currentNowMa" to cachedCurrentNowMa,
            "hasAmbientHardwareSensor" to hasAmbient,
            "ambientTempHardwareC" to cachedAmbientTempHardwareC,
            "pressureHpa" to cachedPressureHpa
        )
    }

    private fun stopMagnetometerListening() {
        sensorEventListener?.let { sensorManager?.unregisterListener(it) }
        sensorEventListener = null
        activeSensor = null

        pressureListener?.let { sensorManager?.unregisterListener(it) }
        pressureListener = null
        pressureSensor = null
        cachedPressureHpa = -1.0
    }

    private fun initNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            val thermalChannel = NotificationChannel(
                CHANNEL_THERMAL_ALERT,
                "Peringatan Hawa Panas Ekstrem",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Peringatan saat hawa suhu sekitar mencapai batas bahaya"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
            }
            nm.createNotificationChannel(thermalChannel)

            val magneticChannel = NotificationChannel(
                CHANNEL_MAGNETIC_ALERT,
                "Peringatan Medan Magnet Kritis",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Peringatan saat terdeteksi medan magnet sangat kuat (> 100 µT)"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500)
            }
            nm.createNotificationChannel(magneticChannel)
        }
    }

    private fun showNativeNotification(id: Int, channelId: String, title: String, body: String): Boolean {
        return try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
            initNotificationChannels()

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = if (intent != null) {
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                PendingIntent.getActivity(context, id, intent, flags)
            } else null

            val iconRes = context.applicationInfo.icon.let { if (it != 0) it else android.R.drawable.ic_dialog_alert }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            builder.setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(iconRes)
                .setAutoCancel(true)
                .setPriority(Notification.PRIORITY_HIGH)

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent)
            }

            nm.notify(id, builder.build())
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun cancelNativeNotification(id: Int) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(id)
        } catch (_: Exception) {}
    }

    /// StreamHandler untuk 50 Hz Magnetometer (Survei geomagnetik murni)
    /// Tanpa registerReceiver di dalam loop onSensorChanged
    private inner class MagnetometerStreamHandler : EventChannel.StreamHandler {

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            if (events == null) return
            val sm = sensorManager ?: run {
                events.error("NO_SENSOR_MANAGER", "SensorManager tidak tersedia", null)
                return
            }

            val uncal = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED)
            val cal = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

            if (uncal != null) {
                activeSensor = uncal
                isUncalibrated = true
            } else if (cal != null) {
                activeSensor = cal
                isUncalibrated = false
            } else {
                events.error("NO_SENSOR", "Magnetometer tidak tersedia di perangkat ini", null)
                return
            }

            // Pastikan cache baterai terisi sekali di awal jika masih -1
            if (cachedBatteryTempC <= 0) {
                refreshBatteryStateOnce()
            }

            val pressure = sm.getDefaultSensor(Sensor.TYPE_PRESSURE)
            if (pressure != null) {
                pressureSensor = pressure
                pressureListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        if (event.values.isNotEmpty()) {
                            cachedPressureHpa = event.values[0].toDouble()
                        }
                    }
                    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
                }
                sm.registerListener(pressureListener, pressureSensor, SensorManager.SENSOR_DELAY_NORMAL)
            }

            sensorEventListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    val data = HashMap<String, Any?>()
                    data["timestampNs"] = event.timestamp
                    data["accuracy"] = event.accuracy
                    data["isUncalibrated"] = isUncalibrated

                    if (isUncalibrated && event.values.size >= 6) {
                        data["rawXMicroT"] = event.values[0].toDouble()
                        data["rawYMicroT"] = event.values[1].toDouble()
                        data["rawZMicroT"] = event.values[2].toDouble()
                        data["biasXMicroT"] = event.values[3].toDouble()
                        data["biasYMicroT"] = event.values[4].toDouble()
                        data["biasZMicroT"] = event.values[5].toDouble()
                    } else {
                        data["rawXMicroT"] = event.values[0].toDouble()
                        data["rawYMicroT"] = event.values[1].toDouble()
                        data["rawZMicroT"] = event.values[2].toDouble()
                        data["biasXMicroT"] = 0.0
                        data["biasYMicroT"] = 0.0
                        data["biasZMicroT"] = 0.0
                    }

                    // Ambil dari cache volatile tanpa overhead IPC / syscall di loop 50 Hz
                    data["batteryTempC"] = cachedBatteryTempC
                    data["isCharging"] = cachedIsCharging
                    data["isScreenOn"] = cachedIsScreenOn
                    data["pressureHpa"] = cachedPressureHpa

                    events.success(data)
                }

                override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
            }

            sm.registerListener(sensorEventListener, activeSensor, targetDelayUs)
        }

        override fun onCancel(arguments: Any?) {
            stopMagnetometerListening()
        }
    }

    /// StreamHandler terpisah khusus data termal perangkat (baterai, hardware ambient sensor, charging)
    /// Berjalan secara event-driven via BroadcastReceiver dan sensor listener ambient,
    /// ditambah timer santai 2 detik saat stream aktif.
    private inner class ThermalStreamHandler : EventChannel.StreamHandler {

        private var batteryReceiver: BroadcastReceiver? = null
        private var ambientSensor: Sensor? = null
        private var ambientListener: SensorEventListener? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private var periodicRunnable: Runnable? = null
        private var eventSink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            if (events == null) return

            // 1. BroadcastReceiver untuk ACTION_BATTERY_CHANGED & power events
            batteryReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    updateBatteryFromIntent(intent)
                    events.success(buildThermalDataMap())
                }
            }
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_BATTERY_CHANGED)
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            val stickyIntent = context.registerReceiver(batteryReceiver, filter)
            updateBatteryFromIntent(stickyIntent)

            // 2. Sensor hardware suhu ambien jika tersedia (Sensor.TYPE_AMBIENT_TEMPERATURE)
            val sm = sensorManager
            val ambient = sm?.getDefaultSensor(Sensor.TYPE_AMBIENT_TEMPERATURE)
            if (ambient != null) {
                ambientSensor = ambient
                ambientListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        if (event.values.isNotEmpty()) {
                            cachedAmbientTempHardwareC = event.values[0].toDouble()
                            events.success(buildThermalDataMap())
                        }
                    }
                    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
                }
                sm.registerListener(ambientListener, ambientSensor, SensorManager.SENSOR_DELAY_NORMAL)
            }

            // Kirim snapshot pertama segera
            events.success(buildThermalDataMap())

            // 3. Polling santai setiap 2 detik untuk memeriksa arus baterai dan screen state
            periodicRunnable = object : Runnable {
                override fun run() {
                    updateCurrentNow()
                    updateScreenState()
                    eventSink?.success(buildThermalDataMap())
                    mainHandler.postDelayed(this, 2000L)
                }
            }
            mainHandler.postDelayed(periodicRunnable!!, 2000L)
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            batteryReceiver?.let {
                try {
                    context.unregisterReceiver(it)
                } catch (_: Exception) {}
            }
            batteryReceiver = null

            ambientListener?.let {
                sensorManager?.unregisterListener(it)
            }
            ambientListener = null
            ambientSensor = null

            periodicRunnable?.let {
                mainHandler.removeCallbacks(it)
            }
            periodicRunnable = null
        }
    }
}
