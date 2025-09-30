import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({Key? key}) : super(key: key);

  @override
  _RemoteControlScreenState createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  late List<CameraDescription> _cameras;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  // Backend configuration
  static const String backendUrl = 'http://192.168.1.100:5000'; // Update with your backend IP

  @override
  void initState() {
    super.initState();
    _setupCamera();
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

  @override
  void dispose() {
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

  Future<void> _sendJoystickCommand(double x, double y, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/joystick'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'x': x,
          'y': y,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Joystick command sent: ${data['action']}');
      } else {
        debugPrint('Failed to send joystick command: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Joystick command error: $e');
    }
  }

  Future<void> _sendJoystickRelease(String type) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/joystick/release'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': type}),
      );

      if (response.statusCode == 200) {
        debugPrint('Joystick released: $type');
      } else {
        debugPrint('Failed to release joystick: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Joystick release error: $e');
    }
  }

  Future<void> _sendValveCommand(String endpoint) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Valve command sent: $endpoint - ${data['message'] ?? 'Success'}');

        // Show feedback to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Command executed'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint('Failed to send valve command: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Valve command error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendEmergencyStop() async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/stop'),
        headers: {'Content-Type': 'application/json'},
      );

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 4:3 container for footage
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
          Positioned(top: 20, right: 20, child: _buildControlButtons()),
          // Valve buttons (top left)
          Positioned(top: 20, left: 20, child: _buildTopLeftButtons()),
        ],
      ),
    );
  }

  Widget _buildJoystick(String type, String label) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Joystick(
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
        _controlButton(Icons.stop, "Emergency Stop", _sendEmergencyStop),
        _controlButton(Icons.settings, "Settings", () => debugPrint("Settings")),
      ],
    );
  }

  Widget _buildTopLeftButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconButton(Icons.food_bank, "Food", () => _sendValveCommand("food")),
        _iconButton(Icons.water_drop, "Water", () => _sendValveCommand("water")),
        _iconButton(Icons.medical_services, "Medicine", () => debugPrint("Medicine - Not implemented")),
      ],
    );
  }

  Widget _controlButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: Icon(icon, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class Joystick extends StatefulWidget {
  final Function(double x, double y) onChanged;
  final VoidCallback onReleased;

  const Joystick({Key? key, required this.onChanged, required this.onReleased}) : super(key: key);

  @override
  _JoystickState createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  double _joystickX = 0;
  double _joystickY = 0;
  static const double _joystickRadius = 30;
  static const double _baseRadius = 50;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
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
        widget.onChanged(normalizedX, normalizedY);
      },
      onPanEnd: (details) {
        setState(() {
          _joystickX = 0;
          _joystickY = 0;
        });
        widget.onReleased();
      },
      child: Container(
        width: _baseRadius * 2,
        height: _baseRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
          border: Border.all(color: Colors.white, width: 2),
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
                  color: Colors.grey[600],
                ),
              ),
            ),
            Positioned(
              left: _baseRadius + _joystickX,
              top: _baseRadius + _joystickY,
              child: Transform.rotate(
                angle: atan2(_joystickY, _joystickX),
                child: const Icon(Icons.arrow_forward, color: Colors.blue, size: 24.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}