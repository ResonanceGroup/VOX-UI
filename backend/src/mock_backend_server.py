#!/usr/bin/env python3
"""
Mock Backend Server for Phase 3B testing.

Provides a simple HTTP server that simulates the RV backend API.
Usage: python3 src/mock_backend_server.py [--port 9002]

Endpoints:
  GET /health - Health check
  GET /devices - List all devices
  GET /devices/<device_id> - Get device state
  PUT /devices/<device_id> - Update device state
"""

import argparse
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Mock device data
MOCK_DEVICES: Dict[str, Dict[str, Any]] = {
    "battery": {
        "soc": 85,
        "voltage": 12.6,
        "current": 5.2,
        "power": 65.5,
        "status": "discharging"
    },
    "climate": {
        "cabin_temperature": 72,
        "external_temperature": 68,
        "unit": "F",
        "status": "cooling"
    },
    "solar": {
        "voltage": 18.5,
        "current": 3.2,
        "power": 59.2,
        "status": "active"
    },
    "lights": {
        "main": {"status": True, "brightness": 100},
        "galley": {"status": False, "brightness": 0},
        "bedroom": {"status": True, "brightness": 50}
    },
    "water": {
        "fresh": 85,
        "grey": 30,
        "black": 15,
        "unit": "%"
    }
}


class MockBackendHandler(BaseHTTPRequestHandler):
    """HTTP request handler for mock backend."""

    def log_message(self, format, *args):
        """Override to use our logger."""
        logger.info(f"{self.address_string()} - {format % args}")

    def send_json(self, data: Dict[str, Any], status: int = 200):
        """Send JSON response."""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        """Handle GET requests."""
        path = self.path.rstrip('/')

        if path == '/health':
            self.send_json({"status": "ok", "service": "mock-backend"})

        elif path == '/devices':
            self.send_json({"devices": MOCK_DEVICES})

        elif path.startswith('/devices/'):
            device_id = path.split('/')[-1]
            if device_id in MOCK_DEVICES:
                self.send_json({"device_id": device_id, "data": MOCK_DEVICES[device_id]})
            else:
                self.send_json({"error": f"Device '{device_id}' not found"}, status=404)

        else:
            self.send_json({"error": f"Unknown endpoint: {path}"}, status=404)

    def do_PUT(self):
        """Handle PUT requests."""
        path = self.path.rstrip('/')

        if path.startswith('/devices/'):
            device_id = path.split('/')[-1]
            if device_id not in MOCK_DEVICES:
                self.send_json({"error": f"Device '{device_id}' not found"}, status=404)
                return

            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            try:
                updates = json.loads(body)
                MOCK_DEVICES[device_id].update(updates)
                self.send_json({"device_id": device_id, "data": MOCK_DEVICES[device_id]})
            except json.JSONDecodeError:
                self.send_json({"error": "Invalid JSON"}, status=400)
        else:
            self.send_json({"error": f"Unknown endpoint: {path}"}, status=404)


def main():
    parser = argparse.ArgumentParser(description='Mock Backend Server')
    parser.add_argument('--port', type=int, default=9002, help='Port to listen on')
    args = parser.parse_args()

    server = HTTPServer(('0.0.0.0', args.port), MockBackendHandler)
    logger.info(f"Mock backend server starting on port {args.port}")
    logger.info(f"Endpoints: /health, /devices, /devices/<device_id>")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        server.shutdown()


if __name__ == '__main__':
    main()
