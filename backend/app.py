from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import threading
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all domains

# ESP32 configuration
ESP32_IP = "192.168.4.1"  # Default ESP32 AP IP
ESP32_PORT = 80
ESP32_BASE_URL = f"http://{ESP32_IP}:{ESP32_PORT}"

# Movement state tracking
movement_state = {
    'forward': False,
    'backward': False,
    'left': False,
    'right': False
}

# Valve state tracking
valve_state = {
    'valve1': False,  # Food valve
    'valve2': False   # Water valve
}

def send_esp32_command(endpoint):
    """Send HTTP request to ESP32"""
    try:
        url = f"{ESP32_BASE_URL}/{endpoint}"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            logger.info(f"ESP32 command sent successfully: {endpoint}")
            return True
        else:
            logger.error(f"ESP32 command failed: {endpoint} - Status: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        logger.error(f"ESP32 communication error: {e}")
        return False

def process_joystick_input(x, y, joystick_type):
    """Process joystick input and determine movement commands"""
    global movement_state

    # Dead zone threshold
    DEAD_ZONE = 0.1

    if joystick_type == "Movement":  # Left joystick - forward/backward
        # Reset movement states
        movement_state['forward'] = False
        movement_state['backward'] = False

        if abs(y) > DEAD_ZONE:
            if y < -DEAD_ZONE:  # Joystick up = forward
                movement_state['forward'] = True
                send_esp32_command("forward")
                return "forward"
            elif y > DEAD_ZONE:  # Joystick down = backward
                movement_state['backward'] = True
                send_esp32_command("backward")
                return "backward"
        else:
            send_esp32_command("stop")
            return "stop"

    elif joystick_type == "Camera":  # Right joystick - left/right
        # Reset turning states
        movement_state['left'] = False
        movement_state['right'] = False

        if abs(x) > DEAD_ZONE:
            if x < -DEAD_ZONE:  # Joystick left = turn left
                movement_state['left'] = True
                send_esp32_command("left")
                return "left"
            elif x > DEAD_ZONE:  # Joystick right = turn right
                movement_state['right'] = True
                send_esp32_command("right")
                return "right"
        else:
            send_esp32_command("stop")
            return "stop"

    return "no_action"

@app.route('/')
def index():
    return jsonify({
        "message": "Lakii Car Control Backend",
        "version": "1.0",
        "status": "running"
    })

@app.route('/status')
def status():
    """Get current system status"""
    return jsonify({
        "esp32_ip": ESP32_IP,
        "movement_state": movement_state,
        "valve_state": valve_state,
        "timestamp": time.time()
    })

@app.route('/joystick', methods=['POST'])
def handle_joystick():
    """Handle joystick input from mobile app"""
    try:
        data = request.get_json()
        x = float(data.get('x', 0))
        y = float(data.get('y', 0))
        joystick_type = data.get('type', 'Movement')

        logger.info(f"Joystick input - Type: {joystick_type}, X: {x:.2f}, Y: {y:.2f}")

        action = process_joystick_input(x, y, joystick_type)

        return jsonify({
            "success": True,
            "action": action,
            "x": x,
            "y": y,
            "type": joystick_type
        })

    except Exception as e:
        logger.error(f"Joystick handling error: {e}")
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/joystick/release', methods=['POST'])
def handle_joystick_release():
    """Handle joystick release"""
    try:
        data = request.get_json()
        joystick_type = data.get('type', 'Movement')

        logger.info(f"Joystick released - Type: {joystick_type}")

        # Stop all movement when joystick is released
        send_esp32_command("stop")

        # Reset movement states
        global movement_state
        movement_state = {
            'forward': False,
            'backward': False,
            'left': False,
            'right': False
        }

        return jsonify({
            "success": True,
            "action": "stop",
            "type": joystick_type
        })

    except Exception as e:
        logger.error(f"Joystick release error: {e}")
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/valve1/<action>', methods=['POST'])
def control_valve1(action):
    """Control valve 1 (Food)"""
    try:
        global valve_state

        if action == 'on':
            success = send_esp32_command("valve1_on")
            valve_state['valve1'] = success
            return jsonify({
                "success": success,
                "valve": 1,
                "action": "on",
                "state": valve_state['valve1']
            })
        elif action == 'off':
            success = send_esp32_command("valve1_off")
            valve_state['valve1'] = False if success else valve_state['valve1']
            return jsonify({
                "success": success,
                "valve": 1,
                "action": "off",
                "state": valve_state['valve1']
            })
        else:
            return jsonify({"success": False, "error": "Invalid action"}), 400

    except Exception as e:
        logger.error(f"Valve 1 control error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/valve2/<action>', methods=['POST'])
def control_valve2(action):
    """Control valve 2 (Water)"""
    try:
        global valve_state

        if action == 'on':
            success = send_esp32_command("valve2_on")
            valve_state['valve2'] = success
            return jsonify({
                "success": success,
                "valve": 2,
                "action": "on",
                "state": valve_state['valve2']
            })
        elif action == 'off':
            success = send_esp32_command("valve2_off")
            valve_state['valve2'] = False if success else valve_state['valve2']
            return jsonify({
                "success": success,
                "valve": 2,
                "action": "off",
                "state": valve_state['valve2']
            })
        else:
            return jsonify({"success": False, "error": "Invalid action"}), 400

    except Exception as e:
        logger.error(f"Valve 2 control error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/food', methods=['POST'])
def drop_food():
    """Drop food (activate valve 1)"""
    try:
        # Turn on valve 1 for 2 seconds then turn off
        success1 = send_esp32_command("valve1_on")
        if success1:
            # Use threading to turn off after delay without blocking
            def turn_off_valve():
                time.sleep(2)
                send_esp32_command("valve1_off")
                valve_state['valve1'] = False

            threading.Thread(target=turn_off_valve, daemon=True).start()
            valve_state['valve1'] = True

        return jsonify({
            "success": success1,
            "message": "Food dispensed",
            "duration": 2
        })

    except Exception as e:
        logger.error(f"Food drop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/water', methods=['POST'])
def drop_water():
    """Drop water (activate valve 2)"""
    try:
        # Turn on valve 2 for 3 seconds then turn off
        success1 = send_esp32_command("valve2_on")
        if success1:
            # Use threading to turn off after delay without blocking
            def turn_off_valve():
                time.sleep(3)
                send_esp32_command("valve2_off")
                valve_state['valve2'] = False

            threading.Thread(target=turn_off_valve, daemon=True).start()
            valve_state['valve2'] = True

        return jsonify({
            "success": success1,
            "message": "Water dispensed",
            "duration": 3
        })

    except Exception as e:
        logger.error(f"Water drop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/stop', methods=['POST'])
def emergency_stop():
    """Emergency stop all operations"""
    try:
        # Stop all movement
        success_stop = send_esp32_command("stop")

        # Turn off all valves
        success_valve1 = send_esp32_command("valve1_off")
        success_valve2 = send_esp32_command("valve2_off")

        # Reset states
        global movement_state, valve_state
        movement_state = {
            'forward': False,
            'backward': False,
            'left': False,
            'right': False
        }
        valve_state = {
            'valve1': False,
            'valve2': False
        }

        return jsonify({
            "success": success_stop and success_valve1 and success_valve2,
            "message": "Emergency stop executed",
            "movement_stopped": success_stop,
            "valves_closed": success_valve1 and success_valve2
        })

    except Exception as e:
        logger.error(f"Emergency stop error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/config', methods=['GET', 'POST'])
def config():
    """Get or set ESP32 configuration"""
    global ESP32_IP, ESP32_BASE_URL

    if request.method == 'GET':
        return jsonify({
            "esp32_ip": ESP32_IP,
            "esp32_port": ESP32_PORT,
            "esp32_base_url": ESP32_BASE_URL
        })

    elif request.method == 'POST':
        try:
            data = request.get_json()
            new_ip = data.get('esp32_ip')

            if new_ip:
                ESP32_IP = new_ip
                ESP32_BASE_URL = f"http://{ESP32_IP}:{ESP32_PORT}"

                return jsonify({
                    "success": True,
                    "message": "ESP32 IP updated",
                    "esp32_ip": ESP32_IP,
                    "esp32_base_url": ESP32_BASE_URL
                })
            else:
                return jsonify({"success": False, "error": "No IP provided"}), 400

        except Exception as e:
            logger.error(f"Config update error: {e}")
            return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Lakii Car Control Backend...")
    logger.info(f"ESP32 target: {ESP32_BASE_URL}")
    app.run(host='0.0.0.0', port=5000, debug=False)