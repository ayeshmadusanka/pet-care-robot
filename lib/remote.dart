import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
          ResolutionPreset.high, // Typically supports 4:3 on most devices
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

  void _sendRobotCommand(String command) {
    debugPrint("Command: $command");
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
          Positioned(left: 20, bottom: 50, child: _buildJoystick("Movement")),
          Positioned(right: 20, bottom: 50, child: _buildJoystick("Camera")),
          Positioned(top: 20, right: 20, child: _buildControlButtons()),
          Positioned(top: 20, left: 20, child: _buildTopLeftButtons()),
        ],
      ),
    );
  }

  Widget _buildJoystick(String type) {
    return Joystick(
      onChanged: (x, y) => _sendRobotCommand("$type Joystick - X: ${x.toStringAsFixed(2)}, Y: ${y.toStringAsFixed(2)}"),
      onReleased: () => _sendRobotCommand("$type Joystick Released"),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _controlButton(Icons.add, "Increase Speed"),
        _controlButton(Icons.remove, "Decrease Speed"),
        _controlButton(Icons.settings, "Settings"),
      ],
    );
  }

  Widget _buildTopLeftButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconButton(Icons.food_bank, "Drop Food"),
        _iconButton(Icons.water_drop, "Drop Water"),
        _iconButton(Icons.medical_services, "Mix Medicine"),
      ],
    );
  }

  Widget _controlButton(IconData icon, String command) {
    return GestureDetector(
      onTap: () => _sendRobotCommand(command),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CircleAvatar(
          backgroundColor: Colors.grey[300],
          child: Icon(icon, color: Colors.black),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String command) {
    return GestureDetector(
      onTap: () => _sendRobotCommand(command),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.black),
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
                  color: Colors.grey[500],
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
