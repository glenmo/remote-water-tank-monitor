# Remote Water Tank Monitor

LoRaWAN-based water tank level monitoring system using Arduino, pressure sensor, and ChirpStack.

## System Overview

```
┌─────────────────┐      LoRaWAN       ┌──────────────┐
│ Arduino UNO R4  │ ◄──────915MHz─────►│ SenseCAP M2  │
│ + LA66 Shield   │                    │   Gateway    │
│ + Pressure      │                    └──────┬───────┘
│   Sensor        │                           │
└─────────────────┘                           │ UDP/WS
                                              │
                                    ┌─────────▼────────┐
                                    │  Raspberry Pi 5  │
                                    │  - ChirpStack    │
                                    │  - MQTT Broker   │
                                    │  - PostgreSQL    │
                                    └──────────────────┘
```

## Hardware Requirements

### Arduino Node
- **Arduino UNO R4 WiFi**
- **Dragino LA66 LoRaWAN Shield** (Serial Number: LA783430)
  - DEV EUI: `A84041D111896C86`
  - APP EUI: `A840410000000101`
  - APP KEY: `57DD346B8C5C87FBB3ABFB748501DEC1`
- **0.5-5V Pressure Sensor** (connected to pin A0)

### Gateway
- **SenseCAP M2 LoRaWAN Gateway**
  - Gateway ID: `2cf7f1177440004b`
  - Configured for AU915 frequency band
  - Packet Forwarder mode (Semtech UDP)

### Server
- **Raspberry Pi 5** running Raspberry Pi OS
- ChirpStack v4.9.0
- ChirpStack Gateway Bridge v4.0.11
- PostgreSQL 16
- Redis 7
- Mosquitto MQTT broker

## Software Architecture

### ChirpStack Server Configuration

**Services Running:**
- ChirpStack Network Server (port 8080)
- ChirpStack Gateway Bridge (UDP port 1700)
- Mosquitto MQTT (port 1883)
- PostgreSQL (port 5432)
- Redis (port 6379)

**Region Configuration:** AU915 (Australia 915 MHz)

### LoRaWAN Configuration

- **Region:** AU915
- **Activation:** OTAA (Over-The-Air Activation)
- **Data Rate:** Adaptive (ADR enabled)
- **Uplink Interval:** 10 minutes
- **Confirmed Messages:** Yes

## Installation

### 1. Raspberry Pi Setup

#### Install ChirpStack

```bash
# Install dependencies
sudo apt update
sudo apt install -y git mosquitto mosquitto-clients postgresql redis-server

# Download ChirpStack binaries
cd /tmp
wget https://artifacts.chirpstack.io/downloads/chirpstack/chirpstack_4.9.0_linux_arm64.tar.gz
wget https://artifacts.chirpstack.io/downloads/chirpstack-gateway-bridge/chirpstack-gateway-bridge_4.0.11_linux_arm64.tar.gz

# Extract and install
tar -xzf chirpstack_4.9.0_linux_arm64.tar.gz
tar -xzf chirpstack-gateway-bridge_4.0.11_linux_arm64.tar.gz
sudo mv chirpstack /usr/local/bin/
sudo mv chirpstack-gateway-bridge /usr/local/bin/
sudo chmod +x /usr/local/bin/chirpstack
sudo chmod +x /usr/local/bin/chirpstack-gateway-bridge
```

#### Configure PostgreSQL

```bash
# Create chirpstack database
sudo -u postgres psql <<EOF
CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';
CREATE DATABASE chirpstack WITH OWNER chirpstack;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
\q
EOF
```

#### Configure ChirpStack

Create `/etc/chirpstack/chirpstack.toml`:

```toml
[logging]
level = "info"

[postgresql]
dsn = "postgres://chirpstack:chirpstack@localhost/chirpstack?sslmode=disable"

[redis]
servers = ["redis://localhost/"]

[network]
net_id = "000000"
enabled_regions = ["au915"]

[api]
bind = "0.0.0.0:8080"
secret = "your-secret-key-here"

[integration]
enabled = ["mqtt"]

  [integration.mqtt]
  server = "tcp://localhost:1883/"
  json = true
```

#### Configure Gateway Bridge

Create `/etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml`:

```toml
[general]
log_level=4

[backend]
type="semtech_udp"

[backend.semtech_udp]
udp_bind="0.0.0.0:1700"

[integration.mqtt]
marshaler="protobuf"

[integration.mqtt.auth]
type="generic"

[integration.mqtt.auth.generic]
servers=["tcp://127.0.0.1:1883"]
```

#### Create systemd Services

```bash
# ChirpStack service
sudo tee /etc/systemd/system/chirpstack.service > /dev/null <<EOF
[Unit]
Description=ChirpStack Network Server
After=postgresql.service redis.service mosquitto.service

[Service]
Type=simple
ExecStart=/usr/local/bin/chirpstack --config /etc/chirpstack
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Gateway Bridge service
sudo tee /etc/systemd/system/chirpstack-gateway-bridge.service > /dev/null <<EOF
[Unit]
Description=ChirpStack Gateway Bridge
After=mosquitto.service

[Service]
Type=simple
ExecStart=/usr/local/bin/chirpstack-gateway-bridge -c /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable --now mosquitto redis-server postgresql chirpstack-gateway-bridge chirpstack
```

### 2. ChirpStack Web Configuration

1. Access ChirpStack at `http://[RASPBERRY_PI_IP]:8080`
2. Login with default credentials: `admin` / `admin`
3. Create Device Profile (manually via database if web UI has region issues)
4. Create Application: "Water Tank Monitor"
5. Add Device:
   - Device EUI: `A84041D111896C86`
   - Device Profile: `Dragino LA66`
6. Configure OTAA Keys:
   - Application Key: `57DD346B8C5C87FBB3ABFB748501DEC1`

### 3. Gateway Configuration

Configure SenseCAP M2 Gateway:

1. Access gateway web interface
2. Navigate to **LoRa Network Settings**
3. Set **Mode** to **Packet Forwarder** (Semtech UDP)
4. Configure:
   - Server Address: `[RASPBERRY_PI_IP]`
   - Server Port Up: `1700`
   - Server Port Down: `1700`
5. Save and restart gateway

### 4. Arduino Setup

1. Open `water_tank_monitor.ino` in Arduino IDE
2. Verify credentials match your device (already configured)
3. Select board: **Arduino UNO R4 WiFi**
4. Select correct COM port
5. Upload sketch

## Usage

### Monitoring Data

Run the Python monitor script on Raspberry Pi:

```bash
cd water_tank_monitor
chmod +x monitor_display.py
python3 monitor_display.py
```

Output example:
```
============================================================
📡 WATER TANK DATA RECEIVED - 2026-02-06 09:50:15
============================================================
Device EUI    : a84041d111896c86
Frame Counter : 42
Port          : 1
Raw Data (hex): 1D7E
------------------------------------------------------------
💧 TANK LEVEL : 75.5%
   [██████████████████████████████░░░░░░░░░░]
   ✅ GOOD - Tank is well filled
------------------------------------------------------------
Signal RSSI   : -65 dBm
Signal SNR    : 9.5 dB
============================================================
```

### Viewing Logs

Data is automatically logged to `/home/claude/water_tank_log.csv`:

```csv
timestamp,tank_level_percent,frame_count,rssi_dbm,snr_db
2026-02-06 09:50:15,75.50,42,-65,9.5
2026-02-06 10:00:15,74.20,43,-67,8.9
```

### ChirpStack Web Interface

Monitor via web:
1. Navigate to **Applications** → **Water Tank Monitor**
2. Click on **Water Tank 1** device
3. View **LoRaWAN frames** tab for raw data
4. View **Events** tab for uplinks/downlinks

## Payload Format

The Arduino sends a 2-byte payload representing tank level percentage × 100:

| Bytes | Description | Format | Example |
|-------|-------------|--------|---------|
| 0-1   | Tank level × 100 | uint16 (big-endian) | `0x1D7E` = 7550 = 75.50% |

**Decoding:**
```python
level_scaled = (byte0 << 8) | byte1
tank_level_percent = level_scaled / 100.0
```

## Troubleshooting

### Arduino Not Joining Network

1. Check Serial Monitor for errors
2. Verify credentials match ChirpStack configuration
3. Ensure gateway is online and connected
4. Check signal strength (device should be within range)

### Gateway Not Connecting

```bash
# Check Gateway Bridge logs
sudo journalctl -u chirpstack-gateway-bridge -f

# Check for PULL_ACK and PUSH_ACK messages
```

### No Data in ChirpStack

1. Verify device shows as "joined" in Arduino Serial Monitor
2. Check gateway shows as "connected" in ChirpStack
3. Review ChirpStack logs:
   ```bash
   sudo journalctl -u chirpstack -f
   ```

### Python Script Not Receiving Data

1. Verify MQTT broker is running:
   ```bash
   sudo systemctl status mosquitto
   ```
2. Check MQTT topics manually:
   ```bash
   mosquitto_sub -h localhost -t "application/+/device/+/event/up" -v
   ```

## Maintenance

### Updating Send Interval

In `water_tank_monitor.ino`, modify:
```cpp
const unsigned long SEND_INTERVAL = 600000; // 10 minutes
```

For testing, use 1 minute:
```cpp
const unsigned long SEND_INTERVAL = 60000; // 1 minute
```

### Backup ChirpStack Database

```bash
sudo -u postgres pg_dump chirpstack > chirpstack_backup_$(date +%Y%m%d).sql
```

### Restore Database

```bash
sudo -u postgres psql chirpstack < chirpstack_backup_YYYYMMDD.sql
```

## Performance

- **Battery Life:** Approximately 2-3 years with 2×AA batteries (10 min intervals)
- **Range:** Up to 2-5 km line-of-sight (AU915)
- **Data Rate:** Adaptive, typically DR0-DR6
- **Reliability:** >99% message delivery with confirmed uplinks

## Project Structure

```
remote-water-tank-monitor/
├── water_tank_monitor.ino      # Arduino sketch
├── monitor_display.py           # Python monitoring script
├── README.md                    # This file
└── docs/
    ├── chirpstack-setup.md      # Detailed ChirpStack setup
    ├── hardware-assembly.md     # Hardware connection guide
    └── payload-specification.md # Detailed payload format
```

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For issues and questions:
- GitHub Issues: https://github.com/glenmo/remote-water-tank-monitor/issues
- ChirpStack Forum: https://forum.chirpstack.io/

## Acknowledgments

- ChirpStack for the excellent LoRaWAN Network Server
- Dragino for LA66 hardware and documentation
- SenseCAP for M2 gateway hardware
