from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import os
import logging
import time
import uuid
from datetime import datetime, timezone

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'lakii_secret_key_2024')
CORS(app, origins=["*"])  # Allow all origins for mobile app

# Initialize SocketIO for real-time communication
socketio = SocketIO(app, cors_allowed_origins="*", ping_timeout=60, ping_interval=25)

# Global state management
car_state = {
    'esp32_connected': False,
    'esp32_last_seen': None,
    'esp32_id': None,
    'movement': {
        'forward': False,
        'backward': False,
        'left': False,
        'right': False,
        'speed': 0
    },
    'valves': {
        'valve1': False,  # Food valve
        'valve2': False   # Water valve
    },
    'sensors': {
        'temperature': None,
        'humidity': None,
        'battery_level': None
    },
    'commands_queue': []
}

# Store connected clients
connected_esp32 = {}
connected_mobile_apps = {}

# API Rate limiting (simple implementation)
command_last_sent = {}
COMMAND_RATE_LIMIT = 0.1  # 100ms between commands

def is_rate_limited(command_type, client_id):
    """Simple rate limiting for commands"""
    now = time.time()
    key = f"{command_type}_{client_id}"

    if key in command_last_sent:
        if now - command_last_sent[key] < COMMAND_RATE_LIMIT:
            return True

    command_last_sent[key] = now
    return False

def send_command_to_esp32(command_data):
    """Send command to ESP32 via WebSocket"""
    try:
        if car_state['esp32_connected'] and car_state['esp32_id']:
            socketio.emit('esp32_command', command_data, room=car_state['esp32_id'])
            logger.info(f"Command sent to ESP32: {command_data}")
            return True
        else:
            logger.warning("ESP32 not connected, queuing command")
            car_state['commands_queue'].append(command_data)
            return False
    except Exception as e:
        logger.error(f"Failed to send command to ESP32: {e}")
        return False

def broadcast_state_update():
    """Broadcast current state to all mobile apps"""
    try:
        state_data = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'car_state': car_state,
            'connected_devices': {
                'esp32': len(connected_esp32),
                'mobile_apps': len(connected_mobile_apps)
            }
        }
        socketio.emit('state_update', state_data, room='mobile_apps')
    except Exception as e:
        logger.error(f"Failed to broadcast state update: {e}")

# ===== REST API ENDPOINTS =====

@app.route('/')
def index():
    return jsonify({
        "service": "Lakii Car Control Backend",
        "version": "2.0.0",
        "domain": "laki.clowntoclown.tk",
        "status": "running",
        "endpoints": {
            "websocket": "/socket.io/",
            "api_base": "/api/v1/",
            "health": "/health",
            "status": "/status"
        },
        "esp32_connected": car_state['esp32_connected'],
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.route('/health')
def health_check():
    """Health check endpoint for load balancer"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "esp32_connected": car_state['esp32_connected']
    }), 200

@app.route('/status')
def get_status():
    """Get detailed system status"""
    return jsonify({
        "car_state": car_state,
        "connected_devices": {
            "esp32_count": len(connected_esp32),
            "mobile_app_count": len(connected_mobile_apps),
            "esp32_devices": list(connected_esp32.keys()),
            "mobile_apps": list(connected_mobile_apps.keys())
        },
        "server_info": {
            "domain": "laki.clowntoclown.tk",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "uptime": time.time()
        }
    })

@app.route('/api/v1/joystick', methods=['POST'])
def handle_joystick():
    """Handle joystick input from mobile app"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"success": False, "error": "No data provided"}), 400

        x = float(data.get('x', 0))
        y = float(data.get('y', 0))
        joystick_type = data.get('type', 'Movement')
        client_id = data.get('client_id', 'unknown')

        # Rate limiting
        if is_rate_limited('joystick', client_id):
            return jsonify({"success": False, "error": "Rate limited"}), 429

        logger.info(f"Joystick input - Type: {joystick_type}, X: {x:.2f}, Y: {y:.2f}")

        # Process joystick input
        DEAD_ZONE = 0.15
        action = "stop"

        if joystick_type == "Movement":  # Left joystick - forward/backward
            car_state['movement']['left'] = False
            car_state['movement']['right'] = False

            if abs(y) > DEAD_ZONE:
                if y < -DEAD_ZONE:  # Up = forward
                    action = "forward"
                    car_state['movement']['forward'] = True
                    car_state['movement']['backward'] = False
                elif y > DEAD_ZONE:  # Down = backward
                    action = "backward"
                    car_state['movement']['forward'] = False
                    car_state['movement']['backward'] = True
                car_state['movement']['speed'] = min(abs(y), 1.0)
            else:
                car_state['movement']['forward'] = False
                car_state['movement']['backward'] = False
                car_state['movement']['speed'] = 0

        elif joystick_type == "Camera":  # Right joystick - left/right
            car_state['movement']['forward'] = False
            car_state['movement']['backward'] = False

            if abs(x) > DEAD_ZONE:
                if x < -DEAD_ZONE:  # Left
                    action = "left"
                    car_state['movement']['left'] = True
                    car_state['movement']['right'] = False
                elif x > DEAD_ZONE:  # Right
                    action = "right"
                    car_state['movement']['left'] = False
                    car_state['movement']['right'] = True
                car_state['movement']['speed'] = min(abs(x), 1.0)
            else:
                car_state['movement']['left'] = False
                car_state['movement']['right'] = False
                car_state['movement']['speed'] = 0

        # Send command to ESP32
        command_data = {
            "type": "movement",
            "action": action,
            "x": x,
            "y": y,
            "speed": car_state['movement']['speed'],
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)
        broadcast_state_update()

        return jsonify({
            "success": success,
            "action": action,
            "x": x,
            "y": y,
            "type": joystick_type,
            "speed": car_state['movement']['speed']
        })

    except Exception as e:
        logger.error(f"Joystick handling error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/v1/joystick/release', methods=['POST'])
def handle_joystick_release():
    """Handle joystick release"""
    try:
        data = request.get_json()
        joystick_type = data.get('type', 'Movement')

        logger.info(f"Joystick released - Type: {joystick_type}")

        # Reset movement states
        car_state['movement'] = {
            'forward': False,
            'backward': False,
            'left': False,
            'right': False,
            'speed': 0
        }

        # Send stop command to ESP32
        command_data = {
            "type": "movement",
            "action": "stop",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)
        broadcast_state_update()

        return jsonify({
            "success": success,
            "action": "stop",
            "type": joystick_type
        })

    except Exception as e:
        logger.error(f"Joystick release error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/v1/valve/<int:valve_num>/<action>', methods=['POST'])
def control_valve(valve_num, action):
    """Control valves"""
    try:
        if valve_num not in [1, 2]:
            return jsonify({"success": False, "error": "Invalid valve number"}), 400

        if action not in ['on', 'off']:
            return jsonify({"success": False, "error": "Invalid action"}), 400

        valve_key = f'valve{valve_num}'
        valve_state = action == 'on'
        car_state['valves'][valve_key] = valve_state

        # Send command to ESP32
        command_data = {
            "type": "valve",
            "valve": valve_num,
            "action": action,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)
        broadcast_state_update()

        return jsonify({
            "success": success,
            "valve": valve_num,
            "action": action,
            "state": valve_state
        })

    except Exception as e:
        logger.error(f"Valve control error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/v1/food', methods=['POST'])
def drop_food():
    """Drop food (activate valve 1 with timer)"""
    try:
        duration = request.get_json().get('duration', 2) if request.get_json() else 2

        command_data = {
            "type": "valve_timed",
            "valve": 1,
            "action": "pulse",
            "duration": duration,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)

        # Update state temporarily
        car_state['valves']['valve1'] = True
        broadcast_state_update()

        return jsonify({
            "success": success,
            "message": "Food dispensed",
            "duration": duration,
            "valve": 1
        })

    except Exception as e:
        logger.error(f"Food drop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/v1/water', methods=['POST'])
def drop_water():
    """Drop water (activate valve 2 with timer)"""
    try:
        duration = request.get_json().get('duration', 3) if request.get_json() else 3

        command_data = {
            "type": "valve_timed",
            "valve": 2,
            "action": "pulse",
            "duration": duration,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)

        # Update state temporarily
        car_state['valves']['valve2'] = True
        broadcast_state_update()

        return jsonify({
            "success": success,
            "message": "Water dispensed",
            "duration": duration,
            "valve": 2
        })

    except Exception as e:
        logger.error(f"Water drop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/v1/stop', methods=['POST'])
def emergency_stop():
    """Emergency stop all operations"""
    try:
        # Reset all states
        car_state['movement'] = {
            'forward': False,
            'backward': False,
            'left': False,
            'right': False,
            'speed': 0
        }
        car_state['valves'] = {
            'valve1': False,
            'valve2': False
        }

        # Send emergency stop to ESP32
        command_data = {
            "type": "emergency_stop",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        success = send_command_to_esp32(command_data)
        broadcast_state_update()

        return jsonify({
            "success": success,
            "message": "Emergency stop executed",
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

    except Exception as e:
        logger.error(f"Emergency stop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# ===== WEBSOCKET EVENTS =====

@socketio.on('connect')
def handle_connect():
    logger.info(f"Client connected: {request.sid}")

@socketio.on('disconnect')
def handle_disconnect():
    logger.info(f"Client disconnected: {request.sid}")

    # Remove from connected devices
    if request.sid in connected_esp32:
        del connected_esp32[request.sid]
        car_state['esp32_connected'] = len(connected_esp32) > 0
        car_state['esp32_id'] = None if not connected_esp32 else list(connected_esp32.keys())[0]
        logger.info("ESP32 disconnected")

    if request.sid in connected_mobile_apps:
        del connected_mobile_apps[request.sid]
        logger.info("Mobile app disconnected")

@socketio.on('esp32_register')
def handle_esp32_register(data):
    """ESP32 registration"""
    try:
        esp32_id = data.get('device_id', request.sid)
        connected_esp32[request.sid] = {
            'device_id': esp32_id,
            'connected_at': datetime.now(timezone.utc).isoformat(),
            'last_ping': time.time()
        }

        car_state['esp32_connected'] = True
        car_state['esp32_last_seen'] = datetime.now(timezone.utc).isoformat()
        car_state['esp32_id'] = request.sid

        logger.info(f"ESP32 registered: {esp32_id}")

        # Send queued commands
        for command in car_state['commands_queue']:
            emit('esp32_command', command)
        car_state['commands_queue'].clear()

        emit('esp32_registered', {
            'success': True,
            'server_time': datetime.now(timezone.utc).isoformat()
        })

        broadcast_state_update()

    except Exception as e:
        logger.error(f"ESP32 registration error: {e}")
        emit('esp32_registered', {'success': False, 'error': str(e)})

@socketio.on('mobile_app_register')
def handle_mobile_register(data):
    """Mobile app registration"""
    try:
        app_id = data.get('app_id', request.sid)
        connected_mobile_apps[request.sid] = {
            'app_id': app_id,
            'connected_at': datetime.now(timezone.utc).isoformat(),
            'device_info': data.get('device_info', {})
        }

        # Join mobile apps room for broadcasts
        socketio.server.enter_room(request.sid, 'mobile_apps')

        logger.info(f"Mobile app registered: {app_id}")

        emit('mobile_registered', {
            'success': True,
            'server_time': datetime.now(timezone.utc).isoformat(),
            'car_state': car_state
        })

    except Exception as e:
        logger.error(f"Mobile app registration error: {e}")
        emit('mobile_registered', {'success': False, 'error': str(e)})

@socketio.on('esp32_status')
def handle_esp32_status(data):
    """Handle ESP32 status updates"""
    try:
        car_state['esp32_last_seen'] = datetime.now(timezone.utc).isoformat()

        # Update sensor data
        if 'sensors' in data:
            car_state['sensors'].update(data['sensors'])

        # Update actual valve states from ESP32
        if 'valves' in data:
            car_state['valves'].update(data['valves'])

        # Update actual movement state from ESP32
        if 'movement' in data:
            car_state['movement'].update(data['movement'])

        logger.info(f"ESP32 status updated: {data}")
        broadcast_state_update()

    except Exception as e:
        logger.error(f"ESP32 status handling error: {e}")

@socketio.on('ping')
def handle_ping(data):
    """Handle ping from ESP32"""
    if request.sid in connected_esp32:
        connected_esp32[request.sid]['last_ping'] = time.time()
        car_state['esp32_last_seen'] = datetime.now(timezone.utc).isoformat()

    emit('pong', {'timestamp': datetime.now(timezone.utc).isoformat()})

if __name__ == '__main__':
    logger.info("Starting Lakii Car Control Cloud Backend...")
    logger.info("Domain: https://laki.clowntoclown.tk")
    port = int(os.environ.get('PORT', 5000))
    socketio.run(app, host='0.0.0.0', port=port, debug=False)