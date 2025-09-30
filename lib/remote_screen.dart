import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  String _espIP = '192.168.4.1';
  bool _isConnected = false;
  String _temperature = '--';
  String _humidity = '--';
  Timer? _sensorTimer;
  Timer? _connectionWatchdog;
  int _connectionRetries = 0;
  final int _maxRetries = 3;
  bool _autoReconnect = true;
  DateTime? _lastSuccessfulConnection;
  bool _valve1Status = false;
  bool _valve2Status = false;

  @override
  void initState() {
    super.initState();
    _startConnectionManager();
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    _connectionWatchdog?.cancel();
    super.dispose();
  }

  void _startConnectionManager() {
    _testConnection();
    _connectionWatchdog = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_autoReconnect && !_isConnected && _connectionRetries == 0) {
        _attemptReconnection();
      }
    });
  }

  void _attemptReconnection() {
    if (_connectionRetries < _maxRetries) {
      _connectionRetries++;
      _testConnection();
    } else {
      _connectionRetries = 0;
    }
  }

  void _startSensorReading() {
    _sensorTimer?.cancel();
    _sensorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isConnected) _getSensorData();
    });
  }

  Future<void> _testConnection() async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('http://$_espIP/'),
        headers: {
          'Content-Type': 'text/html',
          'User-Agent': 'Flutter-ESP32-Remote/1.0',
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 5));
      client.close();
      if (response.statusCode == 200) {
        setState(() {
          _isConnected = true;
          _connectionRetries = 0;
          _autoReconnect = true;
          _lastSuccessfulConnection = DateTime.now();
        });
        _startSensorReading();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (_) {
      setState(() {
        _isConnected = false;
        _temperature = '--';
        _humidity = '--';
      });
    }
  }

  Future<void> _getSensorData() async {
    if (!_isConnected) return;
    try {
      final response = await http.get(
        Uri.parse('http://$_espIP/sensor'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Flutter-ESP32-Remote/1.0',
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = data['temperature'] != null
              ? (data['temperature'] as num).toDouble().toStringAsFixed(1)
              : '--';
          _humidity = data['humidity'] != null
              ? (data['humidity'] as num).toDouble().toStringAsFixed(1)
              : '--';
          _lastSuccessfulConnection = DateTime.now();
        });
      }
    } catch (_) {}
  }

  Future<void> _sendCommand(String command) async {
    if (!_isConnected) return;
    try {
      final response = await http.get(
        Uri.parse('http://$_espIP/$command'),
        headers: {
          'Content-Type': 'text/plain',
          'User-Agent': 'Flutter-ESP32-Remote/1.0',
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 || response.statusCode == 303) {
        setState(() {
          _lastSuccessfulConnection = DateTime.now();
          if (command == 'valve1_on') _valve1Status = true;
          if (command == 'valve1_off') _valve1Status = false;
          if (command == 'valve2_on') _valve2Status = true;
          if (command == 'valve2_off') _valve2Status = false;
        });
      }
    } catch (_) {
      setState(() => _isConnected = false);
    }
  }

  Widget _buildControlButton({required String command, required IconData icon}) {
    return SizedBox(
      width: 90,
      height: 50,
      child: ElevatedButton(
        onPressed: () => _sendCommand(command),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }

  Widget _buildValveControl(String valveName, bool status, String onCommand, String offCommand) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(valveName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(
                  status ? 'ON' : 'OFF',
                  style: TextStyle(color: status ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _sendCommand(status ? offCommand : onCommand),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(status ? 'Turn OFF' : 'Turn ON', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Car Remote', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo.shade900,
        actions: [
          Icon(_isConnected ? Icons.wifi : Icons.wifi_off, color: _isConnected ? Colors.green : Colors.red),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.thermostat, size: 28, color: Colors.orange),
                    const SizedBox(height: 4),
                    Text('$_temperature°C', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.water_drop, size: 28, color: Colors.blue),
                    const SizedBox(height: 4),
                    Text('$_humidity%', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                _buildControlButton(command: 'forward', icon: Icons.keyboard_arrow_up),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(command: 'left', icon: Icons.keyboard_arrow_left),
                    _buildControlButton(command: 'stop', icon: Icons.stop),
                    _buildControlButton(command: 'right', icon: Icons.keyboard_arrow_right),
                  ],
                ),
                const SizedBox(height: 12),
                _buildControlButton(command: 'backward', icon: Icons.keyboard_arrow_down),
              ],
            ),
            const SizedBox(height: 24),
            _buildValveControl('Valve 1', _valve1Status, 'valve1_on', 'valve1_off'),
            _buildValveControl('Valve 2', _valve2Status, 'valve2_on', 'valve2_off'),
          ],
        ),
      ),
    );
  }
}