#!/bin/bash

# Lakii Backend - Update Script
# Pull latest changes from git and restart service

set -e

# Configuration
APP_DIR="/opt/lakii"
SERVICE_NAME="lakii-backend"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🔄 Updating Lakii Car Control Backend..."

# Check if running from app directory
if [ ! -f "cloud_app.py" ]; then
    if [ -d "$APP_DIR" ]; then
        cd "$APP_DIR"
        log_info "Changed to application directory: $APP_DIR"
    else
        echo "Error: Could not find application files"
        exit 1
    fi
fi

# Check if git repository
if [ ! -d ".git" ]; then
    echo "Error: Not a git repository. Cannot update."
    echo "Please redeploy using the deployment guide."
    exit 1
fi

# Backup current version (optional)
log_info "Creating backup of current version..."
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "../$BACKUP_DIR"
cp -r . "../$BACKUP_DIR/" 2>/dev/null || log_warning "Backup creation failed"

# Stop the service
log_info "Stopping service..."
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet $SERVICE_NAME; then
        sudo systemctl stop $SERVICE_NAME
        log_success "Service stopped"
    else
        log_warning "Service was not running"
    fi
fi

# Pull latest changes
log_info "Pulling latest changes from git..."
git fetch origin
git pull origin main

if [ $? -eq 0 ]; then
    log_success "Git pull completed"
else
    echo "Error: Git pull failed"
    exit 1
fi

# Update Python dependencies if requirements changed
if git diff HEAD~1 HEAD --name-only | grep -q "cloud_requirements.txt"; then
    log_info "Requirements file changed, updating dependencies..."
    source venv/bin/activate
    pip install -r cloud_requirements.txt
    log_success "Dependencies updated"
fi

# Update file permissions
chmod +x *.sh

# Restart the service
log_info "Starting service..."
if command -v systemctl &> /dev/null; then
    sudo systemctl start $SERVICE_NAME

    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Service started successfully"
    else
        echo "Error: Service failed to start"
        echo "Check logs: sudo journalctl -u $SERVICE_NAME -n 20"
        exit 1
    fi
else
    log_warning "Systemd not available, please start manually with ./start.sh"
fi

# Display status
echo
echo "✅ Update completed successfully!"
echo
echo "📍 Backend URL: http://laki.clowntoclown.tk"
echo "📍 Health Check: http://laki.clowntoclown.tk/health"
echo
echo "📋 Check status: sudo systemctl status $SERVICE_NAME"
echo "📋 View logs: sudo journalctl -u $SERVICE_NAME -f"
echo
echo "🗂️  Backup created at: ../$BACKUP_DIR"
echo