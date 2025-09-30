#!/bin/bash

# Lakii Backend - Start Script

set -e

# Configuration
APP_DIR="/opt/lakii"
SERVICE_NAME="lakii-backend"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo "🚗 Starting Lakii Car Control Backend..."

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

# Start via systemd if available
if command -v systemctl &> /dev/null; then
    log_info "Starting via systemd..."
    sudo systemctl start $SERVICE_NAME
    sudo systemctl status $SERVICE_NAME --no-pager
    log_success "Service started successfully"

    echo
    echo "📍 Backend available at: http://laki.clowntoclown.tk"
    echo "📍 Health check: http://laki.clowntoclown.tk/health"
    echo
    echo "📋 View logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "🛑 Stop service: sudo systemctl stop $SERVICE_NAME"

else
    # Manual start with virtual environment
    log_info "Starting manually with virtual environment..."

    if [ ! -d "venv" ]; then
        echo "Error: Virtual environment not found. Run deploy.sh first."
        exit 1
    fi

    # Load environment variables
    if [ -f ".env" ]; then
        export $(cat .env | grep -v '#' | xargs)
    fi

    # Activate virtual environment and start
    source venv/bin/activate

    echo "Starting Gunicorn server..."
    gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:5000 --timeout 120 cloud_app:app
fi