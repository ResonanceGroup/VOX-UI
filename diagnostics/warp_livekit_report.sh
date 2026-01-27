#!/usr/bin/env bash
set -u

TS=$(date -u +"%Y%m%dT%H%M%SZ" 2>/dev/null || date +"%Y%m%dT%H%M%SZ")
OUTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reports"
mkdir -p "$OUTDIR"
REPORT="$OUTDIR/warp-livekit-report-${TS}.txt"

# Optional overrides
LIVEKIT_HOST_IP="${LIVEKIT_HOST_IP:-}"     # e.g. 10.0.0.128
LIVEKIT_PORT="${LIVEKIT_PORT:-7880}"
TOKEN_SVC_PORT="${TOKEN_SVC_PORT:-8787}"
SSH_PORT="${SSH_PORT:-22}"

redact() {
  sed -E \
    -e 's/(LIVEKIT_API_SECRET=).*/\1[REDACTED]/g' \
    -e 's/(CF_API_TOKEN=).*/\1[REDACTED]/g' \
    -e 's/(CLOUDFLARE_API_TOKEN=).*/\1[REDACTED]/g' \
    -e 's/(TOKEN=).*/\1[REDACTED]/g' \
    -e 's/(PASSWORD=).*/\1[REDACTED]/g' \
    -e 's/(SECRET=).*/\1[REDACTED]/g'
}

section() {
  printf "\n===== %s =====\n" "$1" | tee -a "$REPORT" >/dev/null
}

run() {
  local title="$1"; shift
  section "$title"
  {
    echo "+ $*"
    ("$@" 2>&1 || true)
  } | redact | tee -a "$REPORT" >/dev/null
}

printf "WARP/LiveKit Diagnostics Report\nUTC: %s\nHost: %s\n\n" "$(date -u 2>/dev/null || date)" "$(hostname 2>/dev/null || echo unknown)" > "$REPORT"

run "OS" bash -lc 'uname -a; echo; (lsb_release -a 2>/dev/null || cat /etc/os-release 2>/dev/null || true)'
run "Time" bash -lc 'date; date -u'

run "IPs" bash -lc 'command -v ip >/dev/null 2>&1 && ip -4 addr || (command -v ifconfig >/dev/null 2>&1 && ifconfig) || true'
run "Routes" bash -lc 'command -v ip >/dev/null 2>&1 && ip route || (command -v netstat >/dev/null 2>&1 && netstat -rn) || true'
run "DNS" bash -lc 'cat /etc/resolv.conf 2>/dev/null || true'

run "Listening Ports" bash -lc 'command -v ss >/dev/null 2>&1 && ss -lntup || (command -v netstat >/dev/null 2>&1 && netstat -lntup) || true'

run "Firewall (ufw)" bash -lc 'command -v ufw >/dev/null 2>&1 && sudo -n ufw status verbose || echo "ufw not present or sudo needs password"'
run "Firewall (iptables)" bash -lc 'sudo -n iptables -S 2>/dev/null || echo "iptables not accessible (sudo?)"'

if [ -z "$LIVEKIT_HOST_IP" ]; then
  LIVEKIT_HOST_IP=$( (command -v ip >/dev/null 2>&1 && ip -4 addr show | awk '/inet 10\./{print $2}' | head -n1 | cut -d/ -f1) || true )
fi

section "Target IP/Ports"
{
  echo "LIVEKIT_HOST_IP=${LIVEKIT_HOST_IP:-[not-detected]}"
  echo "LIVEKIT_PORT=${LIVEKIT_PORT}"
  echo "TOKEN_SVC_PORT=${TOKEN_SVC_PORT}"
  echo "SSH_PORT=${SSH_PORT}"
} | tee -a "$REPORT" >/dev/null

if [ -n "$LIVEKIT_HOST_IP" ]; then
  run "Local Port Probes (nc)" bash -lc "command -v nc >/dev/null 2>&1 && (nc -vz -w 2 $LIVEKIT_HOST_IP $SSH_PORT; nc -vz -w 2 $LIVEKIT_HOST_IP $LIVEKIT_PORT; nc -vz -w 2 $LIVEKIT_HOST_IP $TOKEN_SVC_PORT) || echo 'nc not installed'"
else
  section "Local Port Probes (nc)"
  echo "Skipping: LIVEKIT_HOST_IP not detected. Set LIVEKIT_HOST_IP=10.0.0.128 when running." | tee -a "$REPORT" >/dev/null
fi

run "Token Service Health (localhost)" bash -lc "command -v curl >/dev/null 2>&1 && curl -sS -m 3 http://127.0.0.1:$TOKEN_SVC_PORT/health || echo 'curl not installed or service not reachable'"
if [ -n "$LIVEKIT_HOST_IP" ]; then
  run "Token Service Health (LAN IP)" bash -lc "command -v curl >/dev/null 2>&1 && curl -sS -m 3 http://$LIVEKIT_HOST_IP:$TOKEN_SVC_PORT/health || echo 'curl not installed or service not reachable'"
fi

run "Docker Info" bash -lc 'command -v docker >/dev/null 2>&1 && docker info || echo "docker not installed"'
run "Docker Containers" bash -lc 'command -v docker >/dev/null 2>&1 && docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true'

run "cloudflared version" bash -lc 'command -v cloudflared >/dev/null 2>&1 && cloudflared --version || echo "cloudflared not installed"'
run "cloudflared service status" bash -lc 'systemctl status cloudflared --no-pager 2>/dev/null || true'
run "cloudflared logs (last 200)" bash -lc 'journalctl -u cloudflared -n 200 --no-pager 2>/dev/null || true'

section "Next Steps"
{
  echo "If SSH from iPhone fails but local port probes succeed: check Cloudflare WARP device profile split-tunnel includes + route attachment." 
  echo "If ports are closed locally: fix service bind (0.0.0.0) and/or ufw/iptables." 
} | tee -a "$REPORT" >/dev/null

echo
echo "Wrote report: $REPORT"
