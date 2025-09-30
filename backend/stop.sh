#!/bin/bash

# Lakii Backend - Stop Script

set -e

# Configuration
SERVICE_NAME="lakii-backend"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🛑 Stopping Lakii Car Control Backend..."

# Stop via systemd if available
if command -v systemctl &> /dev/null; then
    log_info "Stopping via systemd..."

    if systemctl is-active --quiet $SERVICE_NAME; then
        sudo systemctl stop $SERVICE_NAME
        echo "✅ Service stopped successfully"
    else
        log_warning "Service is not running"
    fi

    # Show status
    sudo systemctl status $SERVICE_NAME --no-pager || true

else
    # Manual stop
    log_info "Stopping manually..."

    # Find and kill Gunicorn processes
    PIDS=$(pgrep -f "gunicorn.*cloud_app" || true)

    if [ -n "$PIDS" ]; then
        echo "Found running processes: $PIDS"
        kill $PIDS
        echo "✅ Processes stopped"
    else
        log_warning "No running processes found"
    fi

    # Also check for Python processes running cloud_app
    PYTHON_PIDS=$(pgrep -f "python.*cloud_app" || true)

    if [ -n "$PYTHON_PIDS" ]; then
        echo "Found Python processes: $PYTHON_PIDS"
        kill $PYTHON_PIDS
        echo "✅ Python processes stopped"
    fi
fi

echo "🏁 Lakii Backend stopped"