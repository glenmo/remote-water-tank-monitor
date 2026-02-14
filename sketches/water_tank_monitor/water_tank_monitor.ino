/*
 * Water Tank Monitor - LoRaWAN Pressure Sensor
 *
 * Hardware:
 * - Arduino UNO R4 WiFi
 * - Dragino LA66 LoRaWAN Shield
 * - 0.5-5V Pressure Sensor on pin A0
 *
 * Device Credentials (from your registration):
 * - DEV EUI: A84041D111896C86
 * - APP EUI: A840410000000101
 * - APP KEY: 57DD346B8C5C87FBB3ABFB748501DEC1
 *
 * Sends pressure sensor data every 10 minutes via LoRaWAN
 */

// LA66 uses Hardware Serial1 on Arduino UNO R4 WiFi
#define LA66_Serial Serial1

// Sensor Configuration
const int PRESSURE_SENSOR_PIN = A0;
const float SENSOR_MIN_VOLTAGE = 0.5;  // Minimum sensor voltage
const float SENSOR_MAX_VOLTAGE = 3.0;  // Maximum sensor voltage
const float ADC_REFERENCE = 5.0;       // Arduino reference voltage
const int ADC_RESOLUTION = 1023;       // 10-bit ADC

// LoRaWAN Credentials
const char* DEV_EUI = "A84041D111896C86";
const char* APP_EUI = "A840410000000101";
const char* APP_KEY = "57DD346B8C5C87FBB3ABFB748501DEC1";

// Timing
unsigned long lastSendTime = 0;
//const unsigned long SEND_INTERVAL = 600000; // 10 minutes (600000ms)
const unsigned long SEND_INTERVAL = 60000;  // 1 minute for testing

// State tracking
bool isJoined = false;
bool isConfigured = false;

void setup() {
  // Initialize Serial for debugging
  Serial.begin(9600);
  while (!Serial && millis() < 5000); // Wait up to 5 seconds for Serial

  Serial.println(F("================================="));
  Serial.println(F("Water Tank Monitor Starting..."));
  Serial.println(F("================================="));

  // Initialize LA66 Serial
  LA66_Serial.begin(9600);
  delay(2000);

  // Configure LA66 Module
  configureLA66();

  // Join LoRaWAN Network
  joinNetwork();

  Serial.println(F("Setup complete. Starting main loop..."));
  Serial.println();
}

void loop() {
  unsigned long currentTime = millis();

  // Check for incoming messages from LA66
  if (LA66_Serial.available()) {
    String response = LA66_Serial.readStringUntil('\n');
    response.trim();
    if (response.length() > 0) {
      Serial.print(F("[LA66] "));
      Serial.println(response);

      // Check for join success
      if (response.indexOf("JOINED") != -1 || response.indexOf("Join Success") != -1) {
        isJoined = true;
        Serial.println(F("*** Successfully joined LoRaWAN network! ***"));
      }
    }
  }

  // Send data at regular intervals
  if (currentTime - lastSendTime >= SEND_INTERVAL) {
    if (isJoined) {
      sendSensorData();
      lastSendTime = currentTime;
    } else {
      Serial.println(F("Not joined to network yet. Attempting to rejoin..."));
      joinNetwork();
      lastSendTime = currentTime;
    }
  }

  delay(100);
}

void configureLA66() {
  Serial.println(F("Configuring LA66 module..."));

  // Reset module
  sendATCommand("ATZ", 2000);
  delay(1000);

  // Set to OTAA mode
  sendATCommand("AT+MODE=OTAA", 1000);

  // Set LoRaWAN credentials
  sendATCommand("AT+DEVEUI=" + String(DEV_EUI), 1000);
  sendATCommand("AT+APPEUI=" + String(APP_EUI), 1000);
  sendATCommand("AT+APPKEY=" + String(APP_KEY), 1000);

  // Set region to AU915 (change if needed: US915, EU868, etc.)
  sendATCommand("AT+DR=AU915", 1000);

  // Enable Adaptive Data Rate
  sendATCommand("AT+ADR=ON", 1000);

  // Set confirmed uplinks (optional, can use AT+CFM=0 for unconfirmed)
  sendATCommand("AT+CFM=1", 1000);

  // Set duty cycle (optional, for regions that require it)
  // sendATCommand("AT+DUTYCYCLE=ON", 1000);

  isConfigured = true;
  Serial.println(F("LA66 configuration complete!"));
  Serial.println();
}

void joinNetwork() {
  Serial.println(F("Joining LoRaWAN network..."));
  Serial.println(F("This may take 10-15 seconds..."));

  sendATCommand("AT+JOIN", 2000);

  // Wait for join response
  unsigned long joinStart = millis();
  while (millis() - joinStart < 30000) { // 30 second timeout
    if (LA66_Serial.available()) {
      String response = LA66_Serial.readStringUntil('\n');
      response.trim();
      if (response.length() > 0) {
        Serial.print(F("[LA66] "));
        Serial.println(response);

        if (response.indexOf("JOINED") != -1 || response.indexOf("Join Success") != -1) {
          isJoined = true;
          Serial.println(F("*** Network join successful! ***"));
          return;
        }

        if (response.indexOf("Join failed") != -1 || response.indexOf("ERROR") != -1) {
          Serial.println(F("*** Network join failed. Will retry later. ***"));
          return;
        }
      }
    }
    delay(100);
  }

  Serial.println(F("Join timeout. Will retry on next send interval."));
}

void sendATCommand(String command, int timeout) {
  Serial.print(F("Sending: "));
  Serial.println(command);

  LA66_Serial.println(command);

  unsigned long startTime = millis();
  while (millis() - startTime < timeout) {
    if (LA66_Serial.available()) {
      String response = LA66_Serial.readStringUntil('\n');
      response.trim();
      if (response.length() > 0) {
        Serial.print(F("  Response: "));
        Serial.println(response);
      }
    }
    delay(10);
  }
}

float readPressureSensor() {
  // Read analog value (average of 10 readings for stability)
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PRESSURE_SENSOR_PIN);
    delay(10);
  }
  int rawValue = sum / 10;

  // Convert to voltage
  float voltage = (rawValue / (float)ADC_RESOLUTION) * ADC_REFERENCE;

  // Convert voltage to percentage (0.5V = 0%, 5.0V = 100%)
  float percentage = ((voltage - SENSOR_MIN_VOLTAGE) /
                     (SENSOR_MAX_VOLTAGE - SENSOR_MIN_VOLTAGE)) * 100.0;

  // Constrain to 0-100%
  percentage = constrain(percentage, 0, 100);

  Serial.println(F("--- Sensor Reading ---"));
  Serial.print(F("Raw ADC: "));
  Serial.println(rawValue);
  Serial.print(F("Voltage: "));
  Serial.print(voltage, 2);
  Serial.println(F(" V"));
  Serial.print(F("Tank Level: "));
  Serial.print(percentage, 1);
  Serial.println(F(" %"));
  Serial.println();

  return percentage;
}

void sendSensorData() {
  Serial.println(F("================================="));
  Serial.println(F("Reading sensor and sending data..."));

  // Read pressure sensor
  float tankLevel = readPressureSensor();

  // Prepare payload
  // Format: 2 bytes for tank level (percentage * 100)
  // Example: 75.5% = 7550 = 0x1D7E
  uint16_t levelScaled = (uint16_t)(tankLevel * 100);

  // Convert to hex string (big-endian)
  String payload = "";
  payload += String((levelScaled >> 8) & 0xFF, HEX);
  if (payload.length() < 2) payload = "0" + payload;

  String lowByte = String(levelScaled & 0xFF, HEX);
  if (lowByte.length() < 2) lowByte = "0" + lowByte;
  payload += lowByte;

  payload.toUpperCase();

  Serial.print(F("Payload (hex): "));
  Serial.println(payload);
  Serial.print(F("Payload (decimal): "));
  Serial.print(levelScaled);
  Serial.println(F(" (tank level * 100)"));

  // Send via LoRaWAN
  String command = "AT+MSG=" + payload;
  Serial.print(F("Sending: "));
  Serial.println(command);

  LA66_Serial.println(command);

  // Wait for response
  unsigned long startTime = millis();
  bool success = false;
  while (millis() - startTime < 10000) { // 10 second timeout
    if (LA66_Serial.available()) {
      String response = LA66_Serial.readStringUntil('\n');
      response.trim();
      if (response.length() > 0) {
        Serial.print(F("[LA66] "));
        Serial.println(response);

        if (response.indexOf("OK") != -1 || response.indexOf("Done") != -1) {
          success = true;
        }

        if (response.indexOf("ERROR") != -1 || response.indexOf("Not joined") != -1) {
          Serial.println(F("Send failed! Will attempt rejoin on next cycle."));
          isJoined = false;
          break;
        }
      }
    }
    delay(100);
  }

  if (success) {
    Serial.println(F("*** Data sent successfully! ***"));
  } else {
    Serial.println(F("*** Send timeout or failed ***"));
  }

  Serial.println(F("================================="));
  Serial.println();
}
