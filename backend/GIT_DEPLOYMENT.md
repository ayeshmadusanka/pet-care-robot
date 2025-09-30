# 🚀 Lakii Car Control - Git Deployment Guide

Deploy your Lakii backend to `laki.clowntoclown.tk` by cloning the repository and running automated deployment scripts.

## 📋 Prerequisites

- **Server**: Ubuntu 18.04+, Debian 10+, CentOS 7+, or RHEL 7+
- **Root Access**: Required for initial setup
- **Domain**: `laki.clowntoclown.tk` pointing to your server IP
- **Port Access**: 80 (HTTP) and 443 (HTTPS) open

## 🔧 One-Command Deployment

### Step 1: Clone and Deploy

```bash
# On your server (as root)
git clone https://github.com/yourusername/lakii.git
cd lakii/backend
chmod +x deploy.sh
sudo ./deploy.sh
```

**That's it!** The script will:
- ✅ Install all system dependencies
- ✅ Setup Python virtual environment
- ✅ Configure Nginx reverse proxy
- ✅ Create systemd service
- ✅ Setup SSL (optional)
- ✅ Configure firewall
- ✅ Start all services

### Step 2: Test Deployment

```bash
# Check if backend is running
curl http://laki.clowntoclown.tk/health

# Expected response:
# {"status": "healthy", "timestamp": "...", "esp32_connected": false}
```

## 📁 Files Created During Deployment

```
/opt/lakii/                    # Application directory
├── cloud_app.py              # Main Flask application
├── venv/                     # Python virtual environment
├── .env                      # Environment configuration
├── logs/                     # Application logs
│   ├── access.log           # Nginx access logs
│   ├── error.log            # Nginx error logs
│   └── lakii.log            # Application logs
└── *.sh                     # Management scripts

/etc/systemd/system/
└── lakii-backend.service     # Systemd service file

/etc/nginx/sites-available/
└── lakii                    # Nginx configuration
```

## 🎛️ Management Commands

### Service Control
```bash
# Start the backend
sudo systemctl start lakii-backend

# Stop the backend
sudo systemctl stop lakii-backend

# Restart the backend
sudo systemctl restart lakii-backend

# Check status
sudo systemctl status lakii-backend

# View logs
sudo journalctl -u lakii-backend -f
```

### Quick Scripts
```bash
cd /opt/lakii

# Start (uses systemd if available)
./start.sh

# Stop
./stop.sh

# Update from git
./update.sh
```

## 🔄 Update Process

When you push changes to your git repository:

```bash
# On your server
cd /opt/lakii
sudo ./update.sh
```

This will:
1. Pull latest changes from git
2. Update dependencies if needed
3. Restart the service
4. Verify everything is working

## 🛠️ Configuration

### Environment Variables

Edit `/opt/lakii/.env`:

```env
SECRET_KEY=your_secret_key_here
PORT=5000
FLASK_ENV=production
DOMAIN=laki.clowntoclown.tk
LOG_LEVEL=INFO
```

### Nginx Configuration

Located at `/etc/nginx/sites-available/lakii`:

- **Rate Limiting**: API calls limited to prevent abuse
- **WebSocket Support**: For real-time communication
- **SSL Ready**: Automatic HTTPS redirect when SSL is enabled
- **Security Headers**: XSS protection, CSRF protection, etc.

### Systemd Service

Located at `/etc/systemd/system/lakii-backend.service`:

- **Auto-restart**: Restarts automatically if it crashes
- **Security**: Runs with limited privileges
- **Logging**: Structured logging to files

## 🔐 SSL Setup (Optional)

The deployment script offers automatic SSL setup with Let's Encrypt:

```bash
# During deployment, choose 'y' when asked about SSL
# Or run manually after deployment:
sudo certbot --nginx -d laki.clowntoclown.tk

# Auto-renewal is automatically configured
```

## 🌐 Network Configuration

### Firewall Rules
```bash
# Automatically configured during deployment
sudo ufw status

# Should show:
# 22/tcp (SSH)
# 80/tcp (HTTP)
# 443/tcp (HTTPS)
```

### DNS Setup
Ensure your domain points to your server:
```bash
# Check DNS resolution
nslookup laki.clowntoclown.tk

# Should return your server's IP address
```

## 📊 Monitoring

### Health Checks

```bash
# Basic health check
curl http://laki.clowntoclown.tk/health

# Detailed status
curl http://laki.clowntoclown.tk/status

# WebSocket test (in browser console)
const socket = io('http://laki.clowntoclown.tk');
socket.on('connect', () => console.log('Connected!'));
```

### Log Locations

```bash
# Application logs
tail -f /opt/lakii/logs/lakii.log

# Systemd service logs
sudo journalctl -u lakii-backend -f

# Nginx access logs
tail -f /opt/lakii/logs/access.log

# Nginx error logs
tail -f /opt/lakii/logs/error.log
```

### Performance Monitoring

```bash
# Check resource usage
htop

# Check service status
systemctl status lakii-backend nginx

# Check open connections
netstat -tulpn | grep :5000
netstat -tulpn | grep :80
```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check service status
sudo systemctl status lakii-backend

# View detailed logs
sudo journalctl -u lakii-backend -n 50

# Check if port is in use
sudo netstat -tulpn | grep :5000

# Test configuration
cd /opt/lakii
source venv/bin/activate
python cloud_app.py
```

### Nginx Issues

```bash
# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### ESP32 Connection Issues

```bash
# Check if backend is accessible
curl http://laki.clowntoclown.tk/health

# Check WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" \
     http://laki.clowntoclown.tk/socket.io/

# Check for ESP32 connections in logs
sudo journalctl -u lakii-backend -f | grep ESP32
```

### Mobile App Issues

```bash
# Test API endpoints
curl -X POST http://laki.clowntoclown.tk/api/v1/stop

# Check CORS headers
curl -H "Origin: http://localhost" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS http://laki.clowntoclown.tk/api/v1/joystick
```

## 🔧 Manual Installation (Alternative)

If the automated script doesn't work for your system:

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip python3-venv nginx git

# CentOS/RHEL
sudo yum install python3 python3-pip git epel-release
sudo yum install nginx
```

### 2. Setup Application

```bash
# Clone repository
git clone https://github.com/yourusername/lakii.git
sudo mv lakii/backend /opt/lakii
cd /opt/lakii

# Create virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r cloud_requirements.txt

# Create environment file
sudo cp .env.example .env
# Edit .env with your settings
```

### 3. Configure Services

```bash
# Copy and enable systemd service
sudo cp lakii-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable lakii-backend

# Configure Nginx
sudo cp nginx.conf /etc/nginx/sites-available/lakii
sudo ln -s /etc/nginx/sites-available/lakii /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Start services
sudo systemctl start lakii-backend
sudo systemctl start nginx
```

## 📞 Getting Help

### Debug Information to Collect

When reporting issues, include:

```bash
# System information
uname -a
cat /etc/os-release

# Service status
sudo systemctl status lakii-backend
sudo systemctl status nginx

# Recent logs
sudo journalctl -u lakii-backend -n 20
sudo tail -n 20 /opt/lakii/logs/error.log

# Network status
curl -v http://laki.clowntoclown.tk/health
sudo netstat -tulpn | grep -E ":(80|443|5000)"
```

### Common Solutions

#### Permission Issues
```bash
sudo chown -R www-data:www-data /opt/lakii
sudo chmod +x /opt/lakii/*.sh
```

#### Port Conflicts
```bash
# Check what's using port 5000
sudo lsof -i :5000

# Kill conflicting process
sudo kill $(sudo lsof -t -i:5000)
```

#### SSL Issues
```bash
# Renew certificate manually
sudo certbot renew

# Test SSL configuration
sudo nginx -t
openssl s_client -connect laki.clowntoclown.tk:443
```

## 🚀 Performance Tuning

### For High Traffic

Edit `/etc/systemd/system/lakii-backend.service`:

```ini
# Increase workers for high traffic
ExecStart=/opt/lakii/venv/bin/gunicorn --worker-class eventlet -w 4 --bind 0.0.0.0:5000 cloud_app:app
```

### Nginx Optimization

Edit `/etc/nginx/sites-available/lakii`:

```nginx
# Add to server block
client_max_body_size 10M;
keepalive_timeout 30;
gzip_comp_level 6;

# Connection limiting
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn conn_limit_per_ip 20;
```

## 🎯 Next Steps

After successful deployment:

1. **Test Health Check**: `curl http://laki.clowntoclown.tk/health`
2. **Update ESP32 Code**: Use `esp32_cloud.ino` with your WiFi credentials
3. **Update Android App**: Use `cloud_remote.dart` with domain URL
4. **Setup Monitoring**: Consider adding Prometheus/Grafana
5. **Backup Strategy**: Setup automated backups of `/opt/lakii`

Your Lakii car control system is now ready for production use! 🚗💨