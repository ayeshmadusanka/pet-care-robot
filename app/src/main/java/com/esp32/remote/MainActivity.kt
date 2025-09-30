package com.esp32.remote

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.esp32.remote.databinding.ActivityMainBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var wifiManager: WifiManager
    private lateinit var connectivityManager: ConnectivityManager
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()

    private val esp32BaseUrl = "http://192.168.4.1"
    private var isConnected = false

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.all { it.value }
        if (allGranted) {
            setupWifiConnection()
        } else {
            Toast.makeText(this, "Location permission required for WiFi operations", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        setupUI()
        checkPermissions()
    }

    private fun checkPermissions() {
        val permissions = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        if (permissions.isNotEmpty()) {
            requestPermissionLauncher.launch(permissions.toTypedArray())
        } else {
            setupWifiConnection()
        }
    }

    private fun setupUI() {
        binding.connectButton.setOnClickListener {
            if (isConnected) {
                disconnectFromESP32()
            } else {
                connectToESP32()
            }
        }

        setupMovementButtons()
        setupValveButtons()
    }

    private fun setupMovementButtons() {
        binding.forwardButton.setOnClickListener { sendCommand("/forward") }
        binding.backwardButton.setOnClickListener { sendCommand("/backward") }
        binding.leftButton.setOnClickListener { sendCommand("/left") }
        binding.rightButton.setOnClickListener { sendCommand("/right") }
        binding.stopButton.setOnClickListener { sendCommand("/stop") }
    }

    private fun setupValveButtons() {
        binding.valve1OnButton.setOnClickListener { sendCommand("/valve1_on") }
        binding.valve1OffButton.setOnClickListener { sendCommand("/valve1_off") }
        binding.valve2OnButton.setOnClickListener { sendCommand("/valve2_on") }
        binding.valve2OffButton.setOnClickListener { sendCommand("/valve2_off") }
    }

    private fun setupWifiConnection() {
        // Check if already connected to ESP32_Car
        val currentNetwork = wifiManager.connectionInfo
        if (currentNetwork.ssid?.contains("ESP32_Car") == true) {
            updateConnectionStatus(true)
        }
    }

    private fun connectToESP32() {
        lifecycleScope.launch {
            try {
                binding.connectButton.text = "Connecting..."
                binding.connectButton.isEnabled = false

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    connectToWifiModern()
                } else {
                    connectToWifiLegacy()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "Connection failed: ${e.message}", Toast.LENGTH_LONG).show()
                    updateConnectionStatus(false)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private suspend fun connectToWifiLegacy() = withContext(Dispatchers.IO) {
        val wifiConfig = WifiConfiguration().apply {
            SSID = "\"ESP32_Car\""
            allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
        }

        val networkId = wifiManager.addNetwork(wifiConfig)
        if (networkId != -1) {
            wifiManager.disconnect()
            wifiManager.enableNetwork(networkId, true)
            wifiManager.reconnect()

            // Wait for connection
            var attempts = 0
            while (attempts < 30) { // 15 seconds timeout
                kotlinx.coroutines.delay(500)
                val info = wifiManager.connectionInfo
                if (info.ssid?.contains("ESP32_Car") == true) {
                    withContext(Dispatchers.Main) {
                        updateConnectionStatus(true)
                        testConnection()
                    }
                    return@withContext
                }
                attempts++
            }

            withContext(Dispatchers.Main) {
                Toast.makeText(this@MainActivity, "Failed to connect to ESP32_Car", Toast.LENGTH_LONG).show()
                updateConnectionStatus(false)
            }
        }
    }

    private fun connectToWifiModern() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val wifiNetworkSpecifier = WifiNetworkSpecifier.Builder()
                .setSsid("ESP32_Car")
                .build()

            val networkRequest = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(wifiNetworkSpecifier)
                .build()

            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    lifecycleScope.launch {
                        updateConnectionStatus(true)
                        testConnection()
                    }
                }

                override fun onUnavailable() {
                    super.onUnavailable()
                    lifecycleScope.launch {
                        Toast.makeText(this@MainActivity, "Failed to connect to ESP32_Car", Toast.LENGTH_LONG).show()
                        updateConnectionStatus(false)
                    }
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    lifecycleScope.launch {
                        updateConnectionStatus(false)
                    }
                }
            }

            connectivityManager.requestNetwork(networkRequest, networkCallback)
        }
    }

    private fun disconnectFromESP32() {
        // For legacy versions, we'd need to manage this differently
        updateConnectionStatus(false)
        Toast.makeText(this, "Disconnected from ESP32_Car", Toast.LENGTH_SHORT).show()
    }

    private fun testConnection() {
        lifecycleScope.launch {
            try {
                val success = withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("$esp32BaseUrl/")
                        .build()

                    try {
                        val response = httpClient.newCall(request).execute()
                        response.isSuccessful
                    } catch (e: IOException) {
                        false
                    }
                }

                if (success) {
                    Toast.makeText(this@MainActivity, "Successfully connected to ESP32!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this@MainActivity, "Connected to WiFi but ESP32 not responding", Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Connection test failed", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updateConnectionStatus(connected: Boolean) {
        isConnected = connected

        binding.statusText.text = if (connected) "Connected" else "Not Connected"
        binding.statusText.setTextColor(
            ContextCompat.getColor(
                this,
                if (connected) android.R.color.holo_green_dark else android.R.color.holo_red_dark
            )
        )

        binding.connectButton.text = if (connected) "Disconnect" else "Connect to ESP32_Car"
        binding.connectButton.isEnabled = true

        // Enable/disable control buttons
        val controlButtons = listOf(
            binding.forwardButton, binding.backwardButton, binding.leftButton,
            binding.rightButton, binding.stopButton, binding.valve1OnButton,
            binding.valve1OffButton, binding.valve2OnButton, binding.valve2OffButton
        )

        controlButtons.forEach { it.isEnabled = connected }
    }

    private fun sendCommand(endpoint: String) {
        if (!isConnected) {
            Toast.makeText(this, "Not connected to ESP32", Toast.LENGTH_SHORT).show()
            return
        }

        lifecycleScope.launch {
            try {
                val success = withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("$esp32BaseUrl$endpoint")
                        .build()

                    try {
                        val response = httpClient.newCall(request).execute()
                        response.isSuccessful
                    } catch (e: IOException) {
                        false
                    }
                }

                if (!success) {
                    Toast.makeText(this@MainActivity, "Command failed", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Error sending command: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }
}