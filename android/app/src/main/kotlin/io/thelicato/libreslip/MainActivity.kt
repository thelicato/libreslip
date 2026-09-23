package io.thelicato.libreslip

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var socket: BluetoothSocket? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> getState(result)
                "requestPermission" -> requestBluetoothPermission(result)
                "openBluetoothSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("invalidAddress", null, null)
                    } else {
                        connect(address, result)
                    }
                }
                "disconnect" -> disconnect(result)
                "send" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val chunkSize = call.argument<Int>("chunkSize") ?: 256
                    if (bytes == null || chunkSize !in 32..1024) {
                        result.error("invalidPayload", null, null)
                    } else {
                        send(bytes, chunkSize, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getState(result: MethodChannel.Result) {
        val adapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
        if (adapter == null) {
            result.success(mapOf("status" to "unsupported", "devices" to emptyList<Any>()))
            return
        }
        if (!hasConnectPermission()) {
            result.success(
                mapOf("status" to "permissionRequired", "devices" to emptyList<Any>()),
            )
            return
        }
        if (!adapter.isEnabled) {
            result.success(mapOf("status" to "disabled", "devices" to emptyList<Any>()))
            return
        }
        val devices = adapter.bondedDevices
            .sortedWith(compareBy({ it.name ?: "" }, { it.address }))
            .map { mapOf("name" to (it.name ?: it.address), "address" to it.address) }
        result.success(
            mapOf(
                "status" to "ready",
                "devices" to devices,
                "connectedAddress" to socket?.takeIf { it.isConnected }?.remoteDevice?.address,
            ),
        )
    }

    private fun requestBluetoothPermission(result: MethodChannel.Result) {
        if (hasConnectPermission()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permissionRequestActive", null, null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), PERMISSION_REQUEST)
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String, result: MethodChannel.Result) {
        if (!hasConnectPermission()) {
            result.error("permissionDenied", null, null)
            return
        }
        executor.execute {
            try {
                closeSocket()
                val adapter =
                    (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
                        ?: throw IOException("Bluetooth unavailable")
                if (!adapter.isEnabled) throw IOException("Bluetooth disabled")
                val device = adapter.bondedDevices.firstOrNull { it.address == address }
                    ?: throw IOException("Device is not paired")
                val candidate =
                    device.createRfcommSocketToServiceRecord(SERIAL_PORT_PROFILE_UUID)
                socket = candidate
                candidate.connect()
                success(result, null)
            } catch (_: SecurityException) {
                error(result, "permissionDenied")
            } catch (_: IOException) {
                closeSocket()
                error(result, "connectionFailed")
            }
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        executor.execute {
            closeSocket()
            success(result, null)
        }
    }

    private fun send(bytes: ByteArray, chunkSize: Int, result: MethodChannel.Result) {
        executor.execute {
            var written = 0
            try {
                val active = socket
                if (active == null || !active.isConnected) {
                    throw IOException("Printer is not connected")
                }
                val output = active.outputStream
                while (written < bytes.size) {
                    val length = minOf(chunkSize, bytes.size - written)
                    output.write(bytes, written, length)
                    output.flush()
                    written += length
                    if (written < bytes.size) Thread.sleep(8)
                }
                success(result, written)
            } catch (_: Exception) {
                closeSocket()
                error(result, "sendFailed", mapOf("bytesWritten" to written))
            }
        }
    }

    private fun hasConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST) {
            val result = permissionResult
            permissionResult = null
            result?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    private fun closeSocket() {
        try {
            socket?.close()
        } catch (_: IOException) {
            // The socket is already unusable.
        } finally {
            socket = null
        }
    }

    private fun success(result: MethodChannel.Result, value: Any?) {
        runOnUiThread { result.success(value) }
    }

    private fun error(
        result: MethodChannel.Result,
        code: String,
        details: Any? = null,
    ) {
        runOnUiThread { result.error(code, null, details) }
    }

    override fun onDestroy() {
        closeSocket()
        executor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_NAME = "io.thelicato.libreslip/printer"
        private const val PERMISSION_REQUEST = 401
        private val SERIAL_PORT_PROFILE_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
