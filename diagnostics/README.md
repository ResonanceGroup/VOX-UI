# Diagnostics

Run the script below on the office Ubuntu host to generate a single report for troubleshooting the WARP + LiveKit setup.

```bash
cd agent-zero-voice-ui
LIVEKIT_HOST_IP=10.0.0.128 bash diagnostics/warp_livekit_report.sh
```

The script writes a timestamped report into `diagnostics/reports/`.

Notes:
- The script avoids printing common secrets.
- It collects networking, firewall, listening ports, Docker, and cloudflared status.
