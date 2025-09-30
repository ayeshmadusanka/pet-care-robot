# 🚗 Lakii Car Control - Cloud Backend

Professional Flask backend for controlling your Lakii car remotely via `laki.clowntoclown.tk`.

## 🌟 Features

- **Real-time WebSocket Communication** - Instant bidirectional updates
- **RESTful API** - Standard HTTP endpoints for all operations
- **Production Ready** - Systemd service, Nginx proxy, SSL support
- **Git Deployment** - One-command deployment from repository
- **Rate Limiting** - Prevents command flooding and abuse
- **Security** - CORS, CSRF protection, input validation
- **Monitoring** - Health checks, logging, status endpoints

## 🚀 Quick Deployment

```bash
# On your server (as root)
git clone https://github.com/yourusername/lakii.git
cd lakii/backend
sudo ./deploy.sh
```

**Done!** Your backend is now running at `http://laki.clowntoclown.tk`

## 📁 Project Structure

```
backend/
├── cloud_app.py              # Main Flask application
├── cloud_requirements.txt    # Python dependencies
├── esp32_cloud.ino          # Updated ESP32 code
├── cloud_remote.dart        # Updated Android app
├── deploy.sh                # One-command deployment
├── start.sh                 # Start service
├── stop.sh                  # Stop service
├── update.sh                # Update from git
├── .gitignore               # Git ignore rules
└── GIT_DEPLOYMENT.md        # Detailed deployment guide
```

## 🌐 API Endpoints

### Base URL: `https://laki.clowntoclown.tk/api/v1`

#### System
- `GET /` - API information
- `GET /health` - Health check for monitoring
- `GET /status` - Detailed system status

#### Movement Control
- `POST /joystick` - Handle joystick input (x, y, type)
- `POST /joystick/release` - Handle joystick release

#### Valve Control
- `POST /food` - Dispense food (2s auto-timer)
- `POST /water` - Dispense water (3s auto-timer)
- `POST /valve/1/on|off` - Manual valve 1 control
- `POST /valve/2/on|off` - Manual valve 2 control

#### Emergency
- `POST /stop` - Emergency stop all operations

## 🔌 WebSocket Events

### Connection URL: `wss://laki.clowntoclown.tk/socket.io/`

#### Client Events
- `mobile_app_register` - Mobile app registration
- `esp32_register` - ESP32 device registration
- `ping` - Keep-alive ping

#### Server Events
- `state_update` - Real-time car state updates
- `esp32_command` - Commands sent to ESP32
- `mobile_registered` - Registration confirmation

## 🔧 Management

### Service Control
```bash
sudo systemctl start|stop|restart lakii-backend
sudo systemctl status lakii-backend
sudo journalctl -u lakii-backend -f
```

### Quick Scripts
```bash
cd /opt/lakii
./start.sh    # Start service
./stop.sh     # Stop service
./update.sh   # Update from git and restart
```

## 📱 Mobile App Integration

Replace `lib/remote.dart` with `cloud_remote.dart` and add to `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  socket_io_client: ^2.0.3+1
```

The app automatically connects to `https://laki.clowntoclown.tk` and provides:
- Real-time connection status
- Rate-limited joystick control
- WebSocket state updates
- Error handling and reconnection

## 🔌 ESP32 Integration

Flash `esp32_cloud.ino` to your ESP32 and update:

```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
```

The ESP32 connects to your WiFi and communicates with the cloud backend via WebSocket.

## 🔄 Update Process

When you push changes to git:

```bash
cd /opt/lakii
sudo ./update.sh
```

Automatically:
- Pulls latest changes
- Updates dependencies if needed
- Restarts service
- Verifies deployment

## 🛡️ Security Features

- **Rate Limiting**: 10 req/s for API, 50 req/s for joystick
- **CORS Protection**: Configured for mobile app origins
- **Input Validation**: All inputs validated and sanitized
- **Security Headers**: XSS, CSRF, clickjacking protection
- **SSL/TLS**: Automatic HTTPS with Let's Encrypt
- **Firewall**: Only necessary ports open

## 📊 Monitoring

### Health Checks
```bash
curl https://laki.clowntoclown.tk/health
```

### Status Information
```bash
curl https://laki.clowntoclown.tk/status
```

### Logs
```bash
# Service logs
sudo journalctl -u lakii-backend -f

# Application logs
tail -f /opt/lakii/logs/lakii.log

# Access logs
tail -f /opt/lakii/logs/access.log
```

## 🐛 Troubleshooting

### Service Issues
```bash
sudo systemctl status lakii-backend
sudo journalctl -u lakii-backend -n 20
```

### Network Issues
```bash
curl -v https://laki.clowntoclown.tk/health
sudo netstat -tulpn | grep :5000
```

### ESP32 Connection
```bash
# Check for ESP32 in logs
sudo journalctl -u lakii-backend -f | grep ESP32
```

## 🎯 Performance

- **WebSocket**: Real-time bidirectional communication
- **Rate Limiting**: Prevents abuse and ensures stability
- **Nginx Proxy**: High-performance reverse proxy
- **Gunicorn**: Production WSGI server with eventlet workers
- **Connection Pooling**: Efficient resource usage

## 📄 Documentation

- **[GIT_DEPLOYMENT.md](GIT_DEPLOYMENT.md)** - Complete deployment guide
- **[deployment_guide.md](deployment_guide.md)** - Original Docker deployment guide

## 🔗 Related Files

- **ESP32 Code**: `esp32_cloud.ino`
- **Android App**: `cloud_remote.dart`
- **Dependencies**: `cloud_requirements.txt`
- **Deployment**: `deploy.sh`

## 📞 Support

When reporting issues, include:
- System information (`uname -a`)
- Service status (`systemctl status lakii-backend`)
- Recent logs (`journalctl -u lakii-backend -n 20`)
- Network status (`curl -v https://laki.clowntoclown.tk/health`)

## 🏷️ Version

**Backend Version**: 2.0.0
**Deployment Type**: Git-based
**Target Domain**: laki.clowntoclown.tk
**Python Version**: 3.9+

## 📜 License

This project is part of the Lakii Car Control System.

---

**Ready to deploy? Run `sudo ./deploy.sh` and your backend will be live in minutes!** 🚀