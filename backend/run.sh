#!/bin/bash

# Lakii Backend Start Script

echo "Starting Lakii Car Control Backend..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Start the Flask application
echo "Starting Flask server..."
echo "Backend will be available at: http://0.0.0.0:5000"
echo "API documentation: http://0.0.0.0:5000/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python app.py