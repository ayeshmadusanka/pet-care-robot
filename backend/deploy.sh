#!/bin/bash

# Lakii Car Control - Git Deployment Script
# Deploy by cloning repository and running this script

set -e  # Exit on any error

echo "🚗 Lakii Car Control - Deployment Script"
echo "========================================"

# Configuration
APP_NAME="lakii-backend"
APP_USER="www-data"
APP_DIR="/opt/lakii"
SERVICE_NAME="lakii-backend"
PYTHON_VERSION="3.9"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root or with sudo"
    exit 1
fi

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    log_info "Detected OS: $OS"
else
    log_error "Cannot detect OS. This script supports Ubuntu/Debian/CentOS/RHEL"
    exit 1
fi

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."

    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update
        apt install -y python3 python3-pip python3-venv nginx git curl wget
        systemctl enable nginx
        systemctl start nginx
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum update -y
        yum install -y python3 python3-pip git curl wget epel-release
        yum install -y nginx
        systemctl enable nginx
        systemctl start nginx
    else
        log_error "Unsupported OS: $OS"
        exit 1
    fi

    log_success "System dependencies installed"
}

# Setup application directory
setup_app_directory() {
    log_info "Setting up application directory..."

    # Create app directory if it doesn't exist
    if [ ! -d "$APP_DIR" ]; then
        mkdir -p $APP_DIR
        log_success "Created directory: $APP_DIR"
    fi

    # Copy files to app directory
    if [ "$(pwd)" != "$APP_DIR" ]; then
        log_info "Copying files to $APP_DIR..."
        cp -r . $APP_DIR/
        cd $APP_DIR
    fi

    # Set permissions
    chown -R $APP_USER:$APP_USER $APP_DIR
    chmod +x $APP_DIR/deploy.sh
    chmod +x $APP_DIR/start.sh
    chmod +x $APP_DIR/stop.sh

    log_success "Application directory setup complete"
}

# Setup Python environment
setup_python_env() {
    log_info "Setting up Python virtual environment..."

    cd $APP_DIR

    # Create virtual environment
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log_success "Created Python virtual environment"
    fi

    # Activate virtual environment and install dependencies
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r cloud_requirements.txt

    log_success "Python environment setup complete"
}

# Create environment file
create_env_file() {
    log_info "Creating environment configuration..."

    if [ ! -f "$APP_DIR/.env" ]; then
        cat > $APP_DIR/.env << EOF
# Lakii Backend Configuration
SECRET_KEY=$(openssl rand -hex 32)
PORT=5000
FLASK_ENV=production
DOMAIN=laki.clowntoclown.tk
PYTHONPATH=$APP_DIR

# Database (if needed)
# DATABASE_URL=sqlite:///$APP_DIR/lakii.db

# Logging
LOG_LEVEL=INFO
LOG_FILE=$APP_DIR/logs/lakii.log
EOF

        chown $APP_USER:$APP_USER $APP_DIR/.env
        chmod 600 $APP_DIR/.env
        log_success "Environment file created"
    else
        log_warning "Environment file already exists, skipping creation"
    fi
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."

    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Lakii Car Control Backend
After=network.target
Wants=network.target

[Service]
Type=exec
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5000 --timeout 120 --access-logfile $APP_DIR/logs/access.log --error-logfile $APP_DIR/logs/error.log cloud_app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Create logs directory
    mkdir -p $APP_DIR/logs
    chown -R $APP_USER:$APP_USER $APP_DIR/logs

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME

    log_success "Systemd service created and enabled"
}

# Configure Nginx
configure_nginx() {
    log_info "Configuring Nginx reverse proxy..."

    # Backup default config if it exists
    if [ -f /etc/nginx/sites-available/default ]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    fi

    # Create Nginx configuration
    cat > /etc/nginx/sites-available/lakii << EOF
server {
    listen 80;
    server_name laki.clowntoclown.tk;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=joystick:10m rate=50r/s;

    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # API rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Joystick endpoint with higher rate limit
    location /api/v1/joystick {
        limit_req zone=joystick burst=50 nodelay;

        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Socket.IO
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Longer timeouts for WebSocket
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Health check (no rate limiting)
    location /health {
        proxy_pass http://127.0.0.1:5000;
        access_log off;
    }

    # Static files (if any)
    location /static/ {
        alias $APP_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/lakii /etc/nginx/sites-enabled/

    # Remove default site if it exists
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm /etc/nginx/sites-enabled/default
    fi

    # Test Nginx configuration
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        log_success "Nginx configuration applied"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
}

# Setup SSL with Certbot (optional)
setup_ssl() {
    read -p "Do you want to setup SSL with Let's Encrypt? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setting up SSL with Certbot..."

        # Install certbot
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            apt install -y certbot python3-certbot-nginx
        elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
            yum install -y certbot python3-certbot-nginx
        fi

        # Get SSL certificate
        certbot --nginx -d laki.clowntoclown.tk --non-interactive --agree-tos --email admin@laki.clowntoclown.tk

        if [ $? -eq 0 ]; then
            log_success "SSL certificate installed"

            # Setup auto-renewal
            echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
            log_success "SSL auto-renewal configured"
        else
            log_warning "SSL setup failed, continuing without SSL"
        fi
    fi
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."

    if command -v ufw &> /dev/null; then
        ufw --force enable
        ufw allow ssh
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw reload
        log_success "UFW firewall configured"
    elif command -v firewalld &> /dev/null; then
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log_success "FirewallD configured"
    else
        log_warning "No firewall detected, please configure manually"
    fi
}

# Start services
start_services() {
    log_info "Starting services..."

    # Start application
    systemctl start $SERVICE_NAME
    systemctl status $SERVICE_NAME --no-pager

    if [ $? -eq 0 ]; then
        log_success "Lakii backend service started successfully"
    else
        log_error "Failed to start Lakii backend service"
        journalctl -u $SERVICE_NAME --no-pager -n 20
        exit 1
    fi

    # Ensure Nginx is running
    systemctl restart nginx
    systemctl status nginx --no-pager

    log_success "All services started successfully"
}

# Display deployment info
show_deployment_info() {
    echo
    echo "🎉 Deployment Complete!"
    echo "====================="
    echo
    echo "📍 Application URL: http://laki.clowntoclown.tk"
    echo "📍 Health Check: http://laki.clowntoclown.tk/health"
    echo "📍 API Base: http://laki.clowntoclown.tk/api/v1/"
    echo
    echo "🔧 Management Commands:"
    echo "   Start:   systemctl start $SERVICE_NAME"
    echo "   Stop:    systemctl stop $SERVICE_NAME"
    echo "   Restart: systemctl restart $SERVICE_NAME"
    echo "   Status:  systemctl status $SERVICE_NAME"
    echo "   Logs:    journalctl -u $SERVICE_NAME -f"
    echo
    echo "📂 Application Directory: $APP_DIR"
    echo "📝 Configuration File: $APP_DIR/.env"
    echo "📋 Log Files: $APP_DIR/logs/"
    echo
    echo "🔄 To update the application:"
    echo "   cd $APP_DIR && git pull && systemctl restart $SERVICE_NAME"
    echo
    echo "⚠️  Next Steps:"
    echo "   1. Update ESP32 code with your WiFi credentials"
    echo "   2. Update Android app with the domain URL"
    echo "   3. Test all functionality"
    echo
}

# Main deployment process
main() {
    log_info "Starting deployment process..."

    install_dependencies
    setup_app_directory
    setup_python_env
    create_env_file
    create_systemd_service
    configure_nginx
    setup_ssl
    setup_firewall
    start_services
    show_deployment_info

    log_success "Deployment completed successfully! 🚗💨"
}

# Check if script should run
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi