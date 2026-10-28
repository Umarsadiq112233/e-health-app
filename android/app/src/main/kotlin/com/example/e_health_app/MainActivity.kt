package com.example.e_health_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var enableResult: MethodChannel.Result? = null
    private var bluetoothChannel: MethodChannel? = null
    private val enableRequestCode = 4817

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bluetoothChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ehealth/bluetooth")
        bluetoothChannel?.setMethodCallHandler { call, result ->
            if (call.method != "requestEnable") { result.notImplemented(); return@setMethodCallHandler }
            if (enableResult != null) { result.error("busy", "Bluetooth request already pending", null); return@setMethodCallHandler }
            if (Build.VERSION.SDK_INT >= 31 && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                result.error("permission_required", "Bluetooth permission is required", null)
                return@setMethodCallHandler
            }
            try {
                val adapter = (getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
                if (adapter == null) { result.success(false); return@setMethodCallHandler }
                if (adapter.isEnabled) { result.success(true); return@setMethodCallHandler }
                enableResult = result
                // Supported Android system prompt; never call the blocked adapter.enable().
                startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), enableRequestCode)
            } catch (error: Exception) {
                Log.e("EHealthBluetooth", "Native enable prompt failed", error)
                enableResult = null
                result.error("enable_unavailable", error.message ?: "Bluetooth enable prompt is unavailable", error.javaClass.simpleName)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == enableRequestCode) {
            val result = enableResult
            enableResult = null
            val enabled = try {
                (getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.isEnabled == true
            } catch (_: SecurityException) { false }
            Log.d("EHealthBluetooth", "Enable completed: result=$resultCode enabled=$enabled")
            result?.success(enabled || resultCode == RESULT_OK)
        }
    }

    override fun onDestroy() {
        enableResult?.success(false)
        enableResult = null
        bluetoothChannel?.setMethodCallHandler(null)
        bluetoothChannel = null
        super.onDestroy()
    }
}
