#!/usr/bin/env python3
"""
Water Tank Monitor - Data Display Script
Subscribes to MQTT and displays incoming water tank data from LoRaWAN

Run on Raspberry Pi ChirpStack server
"""

import paho.mqtt.client as mqtt
import json
import struct
from datetime import datetime
import sys

# MQTT Configuration
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "application/+/device/+/event/up"

# Device EUI (from your configuration)
DEVICE_EUI = "a84041d111896c86"

def decode_payload(hex_data):
    """
    Decode the water tank sensor payload
    Format: 2 bytes representing tank level * 100
    Example: 0x1D7E = 7550 = 75.50%
    """
    try:
        # Convert hex string to bytes
        data_bytes = bytes.fromhacked(hex_data, 'hex')
        
        if len(data_bytes) >= 2:
            # Unpack as big-endian unsigned short
            level_scaled = struct.unpack('>H', data_bytes[:2])[0]
            tank_level = level_scaled / 100.0
            return tank_level
        else:
            return None
    except Exception as e:
        print(f"Error decoding payload: {e}")
        return None

def on_connect(client, userdata, flags, rc):
    """Callback when connected to MQTT broker"""
    if rc == 0:
        print("=" * 60)
        print("Connected to MQTT broker successfully!")
        print(f"Subscribing to: {MQTT_TOPIC}")
        print("=" * 60)
        print()
        client.subscribe(MQTT_TOPIC)
        print("Waiting for water tank data...")
        print()
    else:
        print(f"Connection failed with code {rc}")

def on_message(client, userdata, msg):
    """Callback when message received"""
    try:
        # Parse JSON payload
        payload = json.loads(msg.payload.decode())
        
        # Extract device information
        dev_eui = payload.get('devEUI', payload.get('deviceInfo', {}).get('devEui', 'Unknown'))
        dev_eui_lower = dev_eui.lower()
        
        # Only process messages from our water tank sensor
        if dev_eui_lower != DEVICE_EUI:
            return
        
        # Extract data
        data_hex = payload.get('data', '')
        f_port = payload.get('fPort', 'N/A')
        f_cnt = payload.get('fCnt', 'N/A')
        rssi = payload.get('rxInfo', [{}])[0].get('rssi', 'N/A') if payload.get('rxInfo') else 'N/A'
        snr = payload.get('rxInfo', [{}])[0].get('snr', 'N/A') if payload.get('rxInfo') else 'N/A'
        
        # Get timestamp
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # Decode the payload
        tank_level = decode_payload(data_hex)
        
        # Display results
        print("=" * 60)
        print(f"📡 WATER TANK DATA RECEIVED - {timestamp}")
        print("=" * 60)
        print(f"Device EUI    : {dev_eui}")
        print(f"Frame Counter : {f_cnt}")
        print(f"Port          : {f_port}")
        print(f"Raw Data (hex): {data_hex}")
        print("-" * 60)
        
        if tank_level is not None:
            # Display tank level with visual indicator
            print(f"💧 TANK LEVEL : {tank_level:.1f}%")
            
            # Visual bar
            bar_length = 40
            filled = int((tank_level / 100.0) * bar_length)
            bar = "█" * filled + "░" * (bar_length - filled)
            print(f"   [{bar}]")
            
            # Status indicator
            if tank_level > 75:
                status = "✅ GOOD - Tank is well filled"
            elif tank_level > 40:
                status = "⚠️  MEDIUM - Consider refilling soon"
            elif tank_level > 20:
                status = "🟧 LOW - Refill recommended"
            else:
                status = "🔴 CRITICAL - Refill immediately!"
            
            print(f"   {status}")
        else:
            print("❌ ERROR: Could not decode tank level")
        
        print("-" * 60)
        print(f"Signal RSSI   : {rssi} dBm")
        print(f"Signal SNR    : {snr} dB")
        print("=" * 60)
        print()
        
        # Log to file (optional)
        log_to_file(timestamp, tank_level, f_cnt, rssi, snr)
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
    except Exception as e:
        print(f"Error processing message: {e}")
        import traceback
        traceback.print_exc()

def log_to_file(timestamp, tank_level, frame_count, rssi, snr):
    """Append data to CSV log file"""
    try:
        with open('/home/claude/water_tank_log.csv', 'a') as f:
            # Write header if file is new
            import os
            if os.stat('/home/claude/water_tank_log.csv').st_size == 0:
                f.write("timestamp,tank_level_percent,frame_count,rssi_dbm,snr_db\n")
            
            f.write(f"{timestamp},{tank_level:.2f},{frame_count},{rssi},{snr}\n")
    except Exception as e:
        print(f"Warning: Could not write to log file: {e}")

def main():
    """Main function"""
    print("""
    ╔════════════════════════════════════════════════════════════╗
    ║         Water Tank Monitor - Live Data Display            ║
    ║                                                            ║
    ║  Monitoring device: A84041D111896C86                      ║
    ║  Press Ctrl+C to stop                                     ║
    ╚════════════════════════════════════════════════════════════╝
    """)
    
    # Create MQTT client
    client = mqtt.Client(client_id="water_tank_monitor")
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        # Connect to broker
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        # Start loop
        client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n")
        print("=" * 60)
        print("Monitor stopped by user")
        print("=" * 60)
        client.disconnect()
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
