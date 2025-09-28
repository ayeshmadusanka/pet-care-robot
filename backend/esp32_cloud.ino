#include <DHT.h>
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>

// ===== WiFi Configuration =====
const char* ssid = "YOUR_WIFI_SSID";        // Replace with your WiFi SSID
const char* password = "YOUR_WIFI_PASSWORD"; // Replace with your WiFi password

// ===== Cloud Server Configuration =====
const char* websocket_host = "laki.clowntoclown.tk";
const int websocket_port = 80;
const char* websocket_path = "/socket.io/?EIO=4&transport=websocket";

// ===== DHT22 Settings =====
#define DHTPIN 21
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

// ===== Motor Pins (L298) =====
int IN1 = 12;
int IN2 = 13;
int IN3 = 15;
int IN4 = 2;
int ENA = 14;   // enable left motor
int ENB = 4;    // enable right motor

// ===== Relay / Valve Pins =====
int valve1Pin = 23; // Valve 1 (Food)
int valve2Pin = 22; // Valve 2 (Water)

// ===== LED Status Pin =====
int statusLED = 5;

// ===== WebSocket Client =====
WebSocketsClient webSocket;

// ===== Variables =====
float currentTemp = NAN;
float currentHum = NAN;
unsigned long lastDHTRead = 0;
unsigned long lastPing = 0;
unsigned long lastStatusUpdate = 0;
bool isConnected = false;
String deviceId = "";

// ===== Movement State =====
struct MovementState {
  bool forward = false;
  bool backward = false;
  bool left = false;
  bool right = false;
  float speed = 0.0;
} movementState;

// ===== Valve State =====
struct ValveState {
  bool valve1 = false;
  bool valve2 = false;
} valveState;

// ===== Motor Functions =====
void moveForward(float speed = 1.0) {
  int pwmValue = (int)(255 * speed);
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  analogWrite(ENA, pwmValue);
  analogWrite(ENB, pwmValue);
  movementState.forward = true;
  movementState.backward = false;
  movementState.left = false;
  movementState.right = false;
  movementState.speed = speed;
  Serial.println("Moving Forward - Speed: " + String(speed));
}

void moveBackward(float speed = 1.0) {
  int pwmValue = (int)(255 * speed);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, pwmValue);
  analogWrite(ENB, pwmValue);
  movementState.forward = false;
  movementState.backward = true;
  movementState.left = false;
  movementState.right = false;
  movementState.speed = speed;
  Serial.println("Moving Backward - Speed: " + String(speed));
}

void turnLeft(float speed = 1.0) {
  int pwmValue = (int)(255 * speed);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  analogWrite(ENA, pwmValue);
  analogWrite(ENB, pwmValue);
  movementState.forward = false;
  movementState.backward = false;
  movementState.left = true;
  movementState.right = false;
  movementState.speed = speed;
  Serial.println("Turning Left - Speed: " + String(speed));
}

void turnRight(float speed = 1.0) {
  int pwmValue = (int)(255 * speed);
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, pwmValue);
  analogWrite(ENB, pwmValue);
  movementState.forward = false;
  movementState.backward = false;
  movementState.left = false;
  movementState.right = true;
  movementState.speed = speed;
  Serial.println("Turning Right - Speed: " + String(speed));
}

void stopCar() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, 0);
  analogWrite(ENB, 0);
  movementState.forward = false;
  movementState.backward = false;
  movementState.left = false;
  movementState.right = false;
  movementState.speed = 0.0;
  Serial.println("Car Stopped");
}

// ===== Valve Functions =====
void setValve1(bool state) {
  digitalWrite(valve1Pin, state ? HIGH : LOW);
  valveState.valve1 = state;
  Serial.println("Valve 1 (Food): " + String(state ? "ON" : "OFF"));
}

void setValve2(bool state) {
  digitalWrite(valve2Pin, state ? HIGH : LOW);
  valveState.valve2 = state;
  Serial.println("Valve 2 (Water): " + String(state ? "ON" : "OFF"));
}

void pulseValve(int valveNum, int duration) {
  Serial.println("Pulsing Valve " + String(valveNum) + " for " + String(duration) + " seconds");

  if (valveNum == 1) {
    setValve1(true);
    delay(duration * 1000);
    setValve1(false);
  } else if (valveNum == 2) {
    setValve2(true);
    delay(duration * 1000);
    setValve2(false);
  }
}

// ===== WebSocket Functions =====
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("[WebSocket] Disconnected!");
      isConnected = false;
      digitalWrite(statusLED, LOW);
      break;

    case WStype_CONNECTED:
      Serial.printf("[WebSocket] Connected to: %s\n", payload);
      isConnected = true;
      digitalWrite(statusLED, HIGH);
      registerDevice();
      break;

    case WStype_TEXT:
      Serial.printf("[WebSocket] Received: %s\n", payload);
      handleWebSocketMessage((char*)payload);
      break;

    case WStype_ERROR:
      Serial.printf("[WebSocket] Error: %s\n", payload);
      break;

    default:
      break;
  }
}

void registerDevice() {
  DynamicJsonDocument doc(512);
  doc["event"] = "esp32_register";
  doc["data"]["device_id"] = deviceId;
  doc["data"]["firmware_version"] = "2.0.0";
  doc["data"]["capabilities"] = JsonArray();
  doc["data"]["capabilities"].add("movement");
  doc["data"]["capabilities"].add("valves");
  doc["data"]["capabilities"].add("sensors");

  String message;
  serializeJson(doc, message);
  webSocket.sendTXT(message);
  Serial.println("Device registration sent");
}

void handleWebSocketMessage(String message) {
  DynamicJsonDocument doc(1024);
  deserializeJson(doc, message);

  String event = doc["event"];

  if (event == "esp32_command") {
    handleCommand(doc["data"]);
  } else if (event == "ping") {
    sendPong();
  } else if (event == "esp32_registered") {
    Serial.println("Device registered successfully");
  }
}

void handleCommand(JsonObject command) {
  String type = command["type"];
  String action = command["action"];

  Serial.println("Received command - Type: " + type + ", Action: " + action);

  if (type == "movement") {
    float speed = command["speed"] | 1.0;

    if (action == "forward") {
      moveForward(speed);
    } else if (action == "backward") {
      moveBackward(speed);
    } else if (action == "left") {
      turnLeft(speed);
    } else if (action == "right") {
      turnRight(speed);
    } else if (action == "stop") {
      stopCar();
    }
  }
  else if (type == "valve") {
    int valveNum = command["valve"];
    bool state = (action == "on");

    if (valveNum == 1) {
      setValve1(state);
    } else if (valveNum == 2) {
      setValve2(state);
    }
  }
  else if (type == "valve_timed") {
    int valveNum = command["valve"];
    int duration = command["duration"] | 2;

    if (action == "pulse") {
      pulseValve(valveNum, duration);
    }
  }
  else if (type == "emergency_stop") {
    emergencyStop();
  }

  // Send status update after command execution
  sendStatusUpdate();
}

void emergencyStop() {
  Serial.println("EMERGENCY STOP ACTIVATED");
  stopCar();
  setValve1(false);
  setValve2(false);
}

void sendPong() {
  DynamicJsonDocument doc(256);
  doc["event"] = "pong";
  doc["data"]["timestamp"] = millis();

  String message;
  serializeJson(doc, message);
  webSocket.sendTXT(message);
}

void sendStatusUpdate() {
  DynamicJsonDocument doc(1024);
  doc["event"] = "esp32_status";

  // Movement state
  doc["data"]["movement"]["forward"] = movementState.forward;
  doc["data"]["movement"]["backward"] = movementState.backward;
  doc["data"]["movement"]["left"] = movementState.left;
  doc["data"]["movement"]["right"] = movementState.right;
  doc["data"]["movement"]["speed"] = movementState.speed;

  // Valve state
  doc["data"]["valves"]["valve1"] = valveState.valve1;
  doc["data"]["valves"]["valve2"] = valveState.valve2;

  // Sensor data
  if (!isnan(currentTemp) && !isnan(currentHum)) {
    doc["data"]["sensors"]["temperature"] = currentTemp;
    doc["data"]["sensors"]["humidity"] = currentHum;
  }

  // System info
  doc["data"]["sensors"]["wifi_rssi"] = WiFi.RSSI();
  doc["data"]["sensors"]["uptime"] = millis();
  doc["data"]["sensors"]["free_heap"] = ESP.getFreeHeap();

  String message;
  serializeJson(doc, message);
  webSocket.sendTXT(message);
}

void sendPing() {
  DynamicJsonDocument doc(256);
  doc["event"] = "ping";
  doc["data"]["timestamp"] = millis();

  String message;
  serializeJson(doc, message);
  webSocket.sendTXT(message);
}

// ===== Setup =====
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Lakii Car ESP32 Cloud Client v2.0 ===");

  // Generate device ID
  deviceId = "ESP32_" + String(ESP.getEfuseMac(), HEX);
  Serial.println("Device ID: " + deviceId);

  // Initialize DHT
  dht.begin();

  // Motor pins
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(ENA, OUTPUT); pinMode(ENB, OUTPUT);

  // Valve pins
  pinMode(valve1Pin, OUTPUT);
  pinMode(valve2Pin, OUTPUT);

  // Status LED
  pinMode(statusLED, OUTPUT);
  digitalWrite(statusLED, LOW);

  // Initialize all outputs to safe state
  stopCar();
  setValve1(false);
  setValve2(false);

  // Connect to WiFi
  connectToWiFi();

  // Initialize WebSocket
  webSocket.begin(websocket_host, websocket_port, websocket_path);
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);

  Serial.println("Setup complete");
}

void connectToWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal Strength: ");
    Serial.println(WiFi.RSSI());
  } else {
    Serial.println("\nWiFi Connection Failed!");
    // You might want to restart or try again
  }
}

// ===== Main Loop =====
void loop() {
  // Handle WebSocket
  webSocket.loop();

  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, attempting reconnection...");
    connectToWiFi();
  }

  // Read DHT sensor every 5 seconds
  if (millis() - lastDHTRead > 5000) {
    lastDHTRead = millis();
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    if (!isnan(temp) && !isnan(hum)) {
      currentTemp = temp;
      currentHum = hum;
    }
  }

  // Send periodic ping (every 30 seconds)
  if (isConnected && millis() - lastPing > 30000) {
    lastPing = millis();
    sendPing();
  }

  // Send status update every 10 seconds
  if (isConnected && millis() - lastStatusUpdate > 10000) {
    lastStatusUpdate = millis();
    sendStatusUpdate();
  }

  // Blink status LED when connected
  if (isConnected) {
    static unsigned long lastBlink = 0;
    static bool ledState = false;

    if (millis() - lastBlink > 1000) {
      lastBlink = millis();
      ledState = !ledState;
      digitalWrite(statusLED, ledState ? HIGH : LOW);
    }
  }

  delay(100);
}