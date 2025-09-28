# 🚀 Lakii Car Control - Cloud Deployment Guide

Complete deployment guide for hosting the Flask backend on **laki.clowntoclown.tk**

## 📋 System Architecture

```
Mobile App (Flutter)
    ↓ HTTPS/WebSocket
Flask Backend (Cloud)
    ↓ WebSocket/JSON
ESP32 (WiFi Connected)
    ↓ GPIO/PWM
Motors & Valves
```

## 🌟 Features

- **Real-time WebSocket Communication**
- **RESTful API Endpoints**
- **Rate Limiting & Security**
- **ESP32 Cloud Connectivity**
- **Mobile App Integration**
- **Production-Ready Configuration**

---

## 🔧 Backend Deployment

### Option 1: Docker Deployment (Recommended)

```bash
# Clone your project
cd backend

# Build and run with Docker Compose
docker-compose -f cloud_docker-compose.yml up --build -d

# Check logs
docker-compose logs -f
```

### Option 2: Heroku Deployment

```bash
# Install Heroku CLI and login
heroku login

# Create Heroku app
heroku create laki-car-control

# Set environment variables
heroku config:set SECRET_KEY=your_secret_key_here

# Deploy
git add .
git commit -m "Deploy cloud backend"
git push heroku main

# Check logs
heroku logs --tail
```

### Option 3: VPS/Cloud Server

```bash
# On your server
git clone https://github.com/yourusername/lakii.git
cd lakii/backend

# Install dependencies
pip install -r cloud_requirements.txt

# Run with Gunicorn
gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:80 cloud_app:app
```

---

## 🔌 ESP32 Setup

### 1. Install Required Libraries

In Arduino IDE, install these libraries:
- **WiFi** (ESP32 Core)
- **ArduinoWebsockets** by Markus Sattler
- **ArduinoJson** by Benoit Blanchon
- **DHT sensor library** by Adafruit

### 2. Update ESP32 Code

Replace your ESP32 code with `esp32_cloud.ino` and update:

```cpp
// Update these lines in esp32_cloud.ino
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
```

### 3. Flash ESP32

1. Connect ESP32 to computer
2. Select board: "ESP32 Dev Module"
3. Upload the code
4. Monitor serial output

---

## 📱 Android App Integration

### 1. Add Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  socket_io_client: ^2.0.3+1
  json_annotation: ^4.8.1

dev_dependencies:
  json_serializable: ^6.7.1
  build_runner: ^2.4.7
```

### 2. Replace Remote Control Screen

Replace `lib/remote.dart` with `cloud_remote.dart`

### 3. Run Flutter Commands

```bash
flutter pub get
flutter pub run build_runner build
```

---

## 🌐 API Endpoints

### Base URL: `https://laki.clowntoclown.tk/api/v1`

#### Movement Control
- `POST /joystick` - Joystick input
- `POST /joystick/release` - Joystick release

#### Valve Control
- `POST /valve/1/on` - Turn on valve 1
- `POST /valve/1/off` - Turn off valve 1
- `POST /valve/2/on` - Turn on valve 2
- `POST /valve/2/off` - Turn off valve 2
- `POST /food` - Drop food (2s timer)
- `POST /water` - Drop water (3s timer)

#### System
- `GET /` - API info
- `GET /health` - Health check
- `GET /status` - System status
- `POST /stop` - Emergency stop

### Example API Calls

#### Joystick Control
```http
POST /api/v1/joystick
Content-Type: application/json

{
  "x": 0.5,
  "y": -0.8,
  "type": "Movement",
  "client_id": "MOBILE_123"
}
```

#### Food Drop
```http
POST /api/v1/food
Content-Type: application/json

{
  "duration": 2
}
```

---

## 🔄 WebSocket Events

### Client → Server

#### Mobile App Registration
```json
{
  "event": "mobile_app_register",
  "data": {
    "app_id": "MOBILE_123",
    "device_info": {
      "platform": "flutter",
      "version": "1.0.0"
    }
  }
}
```

#### ESP32 Registration
```json
{
  "event": "esp32_register",
  "data": {
    "device_id": "ESP32_ABC123",
    "firmware_version": "2.0.0",
    "capabilities": ["movement", "valves", "sensors"]
  }
}
```

### Server → Client

#### State Updates (to Mobile Apps)
```json
{
  "event": "state_update",
  "data": {
    "car_state": {
      "movement": {
        "forward": false,
        "speed": 0.0
      },
      "valves": {
        "valve1": false,
        "valve2": false
      },
      "sensors": {
        "temperature": 25.5,
        "humidity": 60.2
      }
    }
  }
}
```

#### Commands (to ESP32)
```json
{
  "event": "esp32_command",
  "data": {
    "type": "movement",
    "action": "forward",
    "speed": 0.8,
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

---

## ⚙️ Configuration

### Environment Variables

Create `.env` file:

```env
SECRET_KEY=your_super_secret_key_here
PORT=5000
FLASK_ENV=production
DOMAIN=laki.clowntoclown.tk
```

### Domain Configuration

For `laki.clowntoclown.tk`:

1. **DNS Setup**: Point domain to your server IP
2. **SSL Certificate**: Use Let's Encrypt or Cloudflare
3. **Reverse Proxy**: Configure Nginx/Apache if needed

### Security Headers

Add to your server config:

```nginx
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
add_header Strict-Transport-Security "max-age=31536000";
```

---

## 🔍 Troubleshooting

### Common Issues

#### ESP32 Connection Problems
```bash
# Check WiFi credentials
Serial.println(WiFi.status());

# Check domain resolution
ping laki.clowntoclown.tk

# Check WebSocket connection
# Look for "Connected to server" in serial monitor
```

#### Mobile App Issues
```dart
// Check connection status
debugPrint('Connected: $isConnected');
debugPrint('ESP32: $esp32Connected');

// Test API endpoints
curl -X GET https://laki.clowntoclown.tk/health
```

#### Backend Issues
```bash
# Check server logs
docker-compose logs lakii-cloud-backend

# Test endpoints
curl -X POST https://laki.clowntoclown.tk/api/v1/stop

# Check WebSocket
# Use browser dev tools or WebSocket test tools
```

### Performance Optimization

#### Rate Limiting
- Joystick commands: 100ms intervals
- Status updates: 10s intervals
- Sensor readings: 5s intervals

#### WebSocket Optimization
- Automatic reconnection
- Ping/pong heartbeat
- Connection pooling

---

## 📊 Monitoring

### Health Checks

```bash
# Server health
curl https://laki.clowntoclown.tk/health

# ESP32 status
curl https://laki.clowntoclown.tk/status
```

### Logging

Check logs for:
- Connection events
- Command execution
- Error messages
- Performance metrics

---

## 🚨 Safety Features

### Emergency Stop
- Available from mobile app
- Stops all movement
- Closes all valves
- Accessible via API: `POST /api/v1/stop`

### Rate Limiting
- Prevents command flooding
- 100ms minimum between joystick commands
- HTTP 429 response for rate limited requests

### Connection Monitoring
- Real-time connection status
- Auto-reconnection for WebSocket
- Timeout handling for HTTP requests

---

## 📝 Testing Checklist

### Pre-Deployment
- [ ] ESP32 connects to WiFi
- [ ] Backend starts without errors
- [ ] Mobile app connects to backend
- [ ] WebSocket communication works
- [ ] API endpoints respond correctly

### Post-Deployment
- [ ] Domain resolves correctly
- [ ] HTTPS/SSL works
- [ ] ESP32 connects to cloud backend
- [ ] Mobile app connects remotely
- [ ] All movement commands work
- [ ] Valve controls function
- [ ] Emergency stop works
- [ ] Real-time updates work

### Load Testing
- [ ] Multiple mobile app connections
- [ ] Rapid joystick movements
- [ ] Long-running connections
- [ ] Network interruption recovery

---

## 🔄 Updates & Maintenance

### Backend Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and deploy
docker-compose -f cloud_docker-compose.yml up --build -d
```

### ESP32 Updates
1. Update code in Arduino IDE
2. Flash to ESP32
3. Monitor serial output for successful connection

### Mobile App Updates
1. Update Flutter code
2. Run `flutter pub get`
3. Test thoroughly before releasing

---

## 📞 Support

### Debug Information
When reporting issues, include:
- Server logs
- ESP32 serial output
- Mobile app debug logs
- Network configuration
- Error messages

### Performance Monitoring
- Connection count
- Command execution time
- Network latency
- Error rates

This deployment guide provides everything needed to host your Lakii car control system on `laki.clowntoclown.tk` with professional-grade features and reliability.