package com.geomag.geomag

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MagnetometerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var sensorManager: SensorManager? = null
    private var sensorEventListener: SensorEventListener? = null
    private var activeSensor: Sensor? = null
    private var isUncalibrated: Boolean = true
    private var targetDelayUs: Int = SensorManager.SENSOR_DELAY_FASTEST

    private var pressureSensor: Sensor? = null
    private var pressureListener: SensorEventListener? = null
    private var lastPressureHpa: Double = -1.0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

        methodChannel = MethodChannel(binding.binaryMessenger, "com.geomag/magnetometer_method")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.geomag/magnetometer_event")
        eventChannel.setStreamHandler(MagnetometerStreamHandler())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
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

    private fun getBatteryTemperature(): Double {
        return try {
            val intentFilter = android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, intentFilter)
            val temp = batteryStatus?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
            if (temp > 0) temp / 10.0 else -1.0
        } catch (e: Exception) {
            -1.0
        }
    }

    private fun isCharging(): Boolean {
        return try {
            val intentFilter = android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, intentFilter)
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        } catch (e: Exception) {
            false
        }
    }

    private fun isScreenOn(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return pm?.isInteractive == true
    }

    private fun stopListening() {
        sensorEventListener?.let { sensorManager?.unregisterListener(it) }
        sensorEventListener = null
        activeSensor = null

        pressureListener?.let { sensorManager?.unregisterListener(it) }
        pressureListener = null
        pressureSensor = null
        lastPressureHpa = -1.0
    }

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

            val pressure = sm.getDefaultSensor(Sensor.TYPE_PRESSURE)
            if (pressure != null) {
                pressureSensor = pressure
                pressureListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        if (event.values.isNotEmpty()) {
                            lastPressureHpa = event.values[0].toDouble()
                        }
                    }
                    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
                }
                sm.registerListener(pressureListener, pressureSensor, SensorManager.SENSOR_DELAY_NORMAL)
            }

            sensorEventListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    val data = HashMap<String, Any>()
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

                    data["batteryTempC"] = getBatteryTemperature()
                    data["isCharging"] = isCharging()
                    data["isScreenOn"] = isScreenOn()
                    data["pressureHpa"] = lastPressureHpa

                    events.success(data)
                }

                override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
            }

            sm.registerListener(sensorEventListener, activeSensor, targetDelayUs)
        }

        override fun onCancel(arguments: Any?) {
            stopListening()
        }
    }
}
