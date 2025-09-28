import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  late List<CameraDescription> _cameras;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  // Cloud Backend Configuration
  static const String backendDomain = 'https://laki.clowntoclown.tk';
  static const String apiBaseUrl = '$backendDomain/api/v1';

  // WebSocket Connection
  late IO.Socket socket;
  bool isConnected = false;
  bool esp32Connected = false;

  // App State
  Map<String, dynamic> carState = {
    'movement': {
      'forward': false,
      'backward': false,
      'left': false,
      'right': false,
      'speed': 0.0
    },
    'valves': {
      'valve1': false,
      'valve2': false
    },
    'sensors': {
      'temperature': null,
      'humidity': null,
      'wifi_rssi': null
    }
  };

  String connectionStatus = 'Disconnected';
  String appId = '';

  @override
  void initState() {
    super.initState();
    appId = 'MOBILE_${DateTime.now().millisecondsSinceEpoch}';
    _setupCamera();
    _initializeWebSocket();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras[0],
          ResolutionPreset.high,
        );
        _initializeControllerFuture = _controller.initialize().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        debugPrint("No cameras available.");
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  void _initializeWebSocket() {
    try {
      socket = IO.io(backendDomain, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      // Connection events
      socket.on('connect', (_) {
        setState(() {
          isConnected = true;
          connectionStatus = 'Connected';
        });
        _registerMobileApp();
        debugPrint('Connected to server');
      });

      socket.on('disconnect', (_) {
        setState(() {
          isConnected = false;
          connectionStatus = 'Disconnected';
        });
        debugPrint('Disconnected from server');
      });

      socket.on('connect_error', (data) {
        setState(() {
          connectionStatus = 'Connection Error';
        });
        debugPrint('Connection error: $data');
      });

      // App-specific events
      socket.on('mobile_registered', (data) {
        debugPrint('Mobile app registered: $data');
        if (data['success'] == true) {
          setState(() {
            carState = data['car_state'] ?? carState;
            esp32Connected = carState['esp32_connected'] ?? false;
          });
        }
      });

      socket.on('state_update', (data) {
        setState(() {
          carState = data['car_state'] ?? carState;
          esp32Connected = carState['esp32_connected'] ?? false;
        });
        debugPrint('State updated: ESP32 connected = $esp32Connected');
      });

      // Connect to server
      socket.connect();
    } catch (e) {
      debugPrint('WebSocket initialization error: $e');
      setState(() {
        connectionStatus = 'Setup Error';
      });
    }
  }

  void _registerMobileApp() {
    socket.emit('mobile_app_register', {
      'app_id': appId,
      'device_info': {
        'platform': 'flutter',
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String()
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    _controller.dispose();
    super.dispose();
  }

  Widget _cameraPreviewWidget() {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CameraPreview(_controller),
      ),
    );
  }

  // HTTP API calls with proper error handling
  Future<bool> _sendJoystickCommand(double x, double y, String type) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/joystick'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'x': x,
          'y': y,
          'type': type,
          'client_id': appId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Joystick command sent: ${data['action']}');
        return data['success'] ?? false;
      } else if (response.statusCode == 429) {
        debugPrint('Rate limited');
        return false;
      } else {
        debugPrint('Failed to send joystick command: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Joystick command error: $e');
      _showErrorSnackBar('Connection timeout');
      return false;
    }
  }

  Future<bool> _sendJoystickRelease(String type) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/joystick/release'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'type': type,
          'client_id': appId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Joystick released: $type');
        return true;
      } else {
        debugPrint('Failed to release joystick: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Joystick release error: $e');
      return false;
    }
  }

  Future<void> _sendValveCommand(String endpoint, {int? duration}) async {
    if (!isConnected || !esp32Connected) {
      _showErrorSnackBar('ESP32 not connected');
      return;
    }

    try {
      Map<String, dynamic> body = {};
      if (duration != null) {
        body['duration'] = duration;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Valve command sent: $endpoint');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Command executed'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('Failed to send valve command: ${response.statusCode}');
        _showErrorSnackBar('Command failed');
      }
    } catch (e) {
      debugPrint('Valve command error: $e');
      _showErrorSnackBar('Connection error');
    }
  }

  Future<void> _sendEmergencyStop() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Emergency stop executed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency stop executed'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Emergency stop error: $e');
      _showErrorSnackBar('Emergency stop failed');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Server: $connectionStatus'),
              Text('ESP32: ${esp32Connected ? "Connected" : "Disconnected"}'),
              const SizedBox(height: 10),
              if (carState['sensors']['temperature'] != null)
                Text('Temperature: ${carState['sensors']['temperature']?.toStringAsFixed(1)}°C'),
              if (carState['sensors']['humidity'] != null)
                Text('Humidity: ${carState['sensors']['humidity']?.toStringAsFixed(1)}%'),
              if (carState['sensors']['wifi_rssi'] != null)
                Text('WiFi Signal: ${carState['sensors']['wifi_rssi']} dBm'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!isConnected) {
                  socket.connect();
                }
                Navigator.of(context).pop();
              },
              child: Text(isConnected ? 'Close' : 'Reconnect'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera preview background
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _cameraPreviewWidget(),
              ),
            ),
          ),

          // Connection status indicator
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.cloud : Icons.cloud_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${esp32Connected ? "ESP32 Connected" : "ESP32 Offline"} | $connectionStatus',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showConnectionDialog,
                    child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),

          // Left joystick - Movement (Forward/Backward)
          Positioned(
            left: 20,
            bottom: 50,
            child: _buildJoystick("Movement", "Forward/Backward"),
          ),

          // Right joystick - Camera (Left/Right)
          Positioned(
            right: 20,
            bottom: 50,
            child: _buildJoystick("Camera", "Left/Right"),
          ),

          // Control buttons (top right)
          Positioned(top: 100, right: 20, child: _buildControlButtons()),

          // Valve buttons (top left)
          Positioned(top: 100, left: 20, child: _buildTopLeftButtons()),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (isConnected && esp32Connected) return Colors.green;
    if (isConnected && !esp32Connected) return Colors.orange;
    return Colors.red;
  }

  Widget _buildJoystick(String type, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Joystick(
          enabled: isConnected && esp32Connected,
          onChanged: (x, y) => _sendJoystickCommand(x, y, type),
          onReleased: () => _sendJoystickRelease(type),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _controlButton(
          Icons.stop,
          "Emergency Stop",
          _sendEmergencyStop,
          Colors.red,
        ),
        _controlButton(
          Icons.settings,
          "Connection Info",
          _showConnectionDialog,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildTopLeftButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconButton(
          Icons.food_bank,
          "Food",
          () => _sendValveCommand("food", duration: 2),
          isEnabled: esp32Connected,
        ),
        _iconButton(
          Icons.water_drop,
          "Water",
          () => _sendValveCommand("water", duration: 3),
          isEnabled: esp32Connected,
        ),
        _iconButton(
          Icons.medical_services,
          "Medicine",
          () => debugPrint("Medicine - Not implemented"),
          isEnabled: false,
        ),
      ],
    );
  }

  Widget _controlButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    Color backgroundColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: CircleAvatar(
            backgroundColor: backgroundColor.withOpacity(0.8),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool isEnabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: isEnabled ? onPressed : null,
          child: CircleAvatar(
            backgroundColor: isEnabled ? Colors.white.withOpacity(0.9) : Colors.grey.withOpacity(0.5),
            child: Icon(
              icon,
              color: isEnabled ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

class Joystick extends StatefulWidget {
  final Function(double x, double y) onChanged;
  final VoidCallback onReleased;
  final bool enabled;

  const Joystick({
    super.key,
    required this.onChanged,
    required this.onReleased,
    this.enabled = true,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  double _joystickX = 0;
  double _joystickY = 0;
  static const double _joystickRadius = 25;
  static const double _baseRadius = 45;

  Timer? _commandTimer;

  @override
  void dispose() {
    _commandTimer?.cancel();
    super.dispose();
  }

  void _throttledCommand(double x, double y) {
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(milliseconds: 100), () {
      widget.onChanged(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: widget.enabled ? (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPosition = box.globalToLocal(details.globalPosition);
        Offset center = Offset(_baseRadius, _baseRadius);
        double distance = (localPosition - center).distance;
        double angle = atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);

        if (distance > _baseRadius - _joystickRadius) {
          _joystickX = (_baseRadius - _joystickRadius) * cos(angle);
          _joystickY = (_baseRadius - _joystickRadius) * sin(angle);
        } else {
          _joystickX = localPosition.dx - center.dx;
          _joystickY = localPosition.dy - center.dy;
        }

        setState(() {});
        double normalizedX = _joystickX / (_baseRadius - _joystickRadius);
        double normalizedY = _joystickY / (_baseRadius - _joystickRadius);
        _throttledCommand(normalizedX, normalizedY);
      } : null,
      onPanEnd: widget.enabled ? (details) {
        setState(() {
          _joystickX = 0;
          _joystickY = 0;
        });
        _commandTimer?.cancel();
        widget.onReleased();
      } : null,
      child: Container(
        width: _baseRadius * 2,
        height: _baseRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.enabled ? Colors.grey[300]?.withOpacity(0.8) : Colors.grey[400]?.withOpacity(0.5),
          border: Border.all(
            color: widget.enabled ? Colors.white : Colors.grey,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: _baseRadius - _joystickRadius + _joystickX,
              top: _baseRadius - _joystickRadius + _joystickY,
              child: Container(
                width: _joystickRadius * 2,
                height: _joystickRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.enabled ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
            if (_joystickX != 0 || _joystickY != 0)
              Positioned(
                left: _baseRadius + _joystickX,
                top: _baseRadius + _joystickY,
                child: Transform.rotate(
                  angle: atan2(_joystickY, _joystickX),
                  child: Icon(
                    Icons.arrow_forward,
                    color: widget.enabled ? Colors.blue : Colors.grey,
                    size: 20.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}