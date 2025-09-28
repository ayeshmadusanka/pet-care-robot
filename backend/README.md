# Lakii Car Control Backend

Flask backend for controlling the Lakii car through ESP32 communication.

## Features

- **Joystick Control**: Handle dual joystick input from mobile app
  - Left joystick: Forward/Backward movement
  - Right joystick: Left/Right turning
- **Valve Control**: Control food and water dispensers
- **Real-time Communication**: Direct HTTP communication with ESP32
- **State Management**: Track movement and valve states
- **CORS Support**: Cross-origin requests from mobile app

## API Endpoints

### Movement Control
- `POST /joystick` - Handle joystick input
- `POST /joystick/release` - Handle joystick release
- `POST /stop` - Emergency stop all operations

### Valve Control
- `POST /valve1/on` - Turn on valve 1 (food)
- `POST /valve1/off` - Turn off valve 1 (food)
- `POST /valve2/on` - Turn on valve 2 (water)
- `POST /valve2/off` - Turn off valve 2 (water)
- `POST /food` - Drop food (auto-timer)
- `POST /water` - Drop water (auto-timer)

### System
- `GET /` - Health check
- `GET /status` - Get current system status
- `GET /config` - Get ESP32 configuration
- `POST /config` - Update ESP32 configuration

## Quick Start

### Development
```bash
cd backend
pip install -r requirements.txt
python app.py
```

### Production with Docker
```bash
cd backend
docker-compose up --build -d
```

### Manual Docker
```bash
cd backend
docker build -t lakii-backend .
docker run -p 5000:5000 lakii-backend
```

## Configuration

### ESP32 Setup
1. Flash the ESP32 with the provided Arduino code
2. ESP32 creates WiFi AP "ESP32_Car" with IP 192.168.4.1
3. Backend automatically connects to this IP

### Mobile App Integration
Update your Flutter app's `_sendRobotCommand` function in `remote.dart`:

```dart
void _sendRobotCommand(String command) async {
  const String backendUrl = 'http://YOUR_BACKEND_IP:5000';

  try {
    if (command.contains('Joystick')) {
      // Parse joystick command and send to backend
      // Example: "Movement Joystick - X: 0.50, Y: -0.75"
      final parts = command.split(' - ');
      final type = parts[0].split(' ')[0]; // "Movement" or "Camera"
      final coords = parts[1].split(', ');
      final x = double.parse(coords[0].split(': ')[1]);
      final y = double.parse(coords[1].split(': ')[1]);

      await http.post(
        Uri.parse('$backendUrl/joystick'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'x': x, 'y': y, 'type': type}),
      );
    } else if (command.contains('Released')) {
      final type = command.split(' ')[0]; // "Movement" or "Camera"
      await http.post(
        Uri.parse('$backendUrl/joystick/release'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': type}),
      );
    } else if (command == 'Drop Food') {
      await http.post(Uri.parse('$backendUrl/food'));
    } else if (command == 'Drop Water') {
      await http.post(Uri.parse('$backendUrl/water'));
    }
  } catch (e) {
    debugPrint('Backend communication error: $e');
  }
}
```

## Network Architecture

```
Mobile App (Flutter)
    ↓ HTTP/REST API
Flask Backend (Python)
    ↓ HTTP GET requests
ESP32 (Arduino/C++)
    ↓ GPIO/PWM signals
Motors & Valves
```

## Deployment Options

### 1. Local Network (Recommended for development)
- Run Flask on your development machine
- Mobile app connects to your machine's IP
- ESP32 creates its own WiFi network

### 2. Cloud Deployment
- Deploy to services like Heroku, DigitalOcean, AWS
- Requires internet connection for both mobile app and ESP32
- ESP32 must connect to internet WiFi instead of AP mode

### 3. Raspberry Pi (Recommended for production)
- Install on Raspberry Pi connected to same network as mobile app
- More reliable than laptop/desktop
- Can be mounted on the car itself

## Troubleshooting

### ESP32 Connection Issues
1. Verify ESP32 is in AP mode and broadcasting "ESP32_Car"
2. Check ESP32 IP is 192.168.4.1
3. Test ESP32 endpoints directly: `curl http://192.168.4.1/forward`

### Backend Issues
1. Check Flask is running on correct port (5000)
2. Verify CORS is enabled for mobile app requests
3. Check logs for ESP32 communication errors

### Mobile App Issues
1. Update backend URL in Flutter code
2. Ensure mobile device can reach backend server
3. Check network connectivity and firewall settings