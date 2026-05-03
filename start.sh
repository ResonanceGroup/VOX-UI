#!/bin/bash
# VoxUI startup script — starts all services in a tmux session
# Usage: bash start.sh [web-port]

set -e
PORT="${1:-3001}"
REPO="$HOME/repos/VOX-UI"
SESSION="voxui"

# Kill existing session if any
tmux kill-session -t "$SESSION" 2>/dev/null || true

tmux new-session -d -s "$SESSION" -x 220 -y 50

# Window 0: LiveKit dev server
tmux rename-window -t "$SESSION:0" "livekit"
tmux send-keys -t "$SESSION:0" "
  $HOME/bin/livekit-server --dev \
    --bind 0.0.0.0 \
    --port 7880 \
    --keys 'devkey:secret'
" Enter

# Window 1: Token + config service
tmux new-window -t "$SESSION" -n "token-svc"
tmux send-keys -t "$SESSION:token-svc" "
  cd $REPO/backend && source .venv/bin/activate
  python src/token_service.py
" Enter

# Window 2: Voice agent
tmux new-window -t "$SESSION" -n "agent"
tmux send-keys -t "$SESSION:agent" "
  sleep 3
  cd $REPO/backend && source .venv/bin/activate
  python src/main.py start
" Enter

# Window 3: Flutter web server
tmux new-window -t "$SESSION" -n "web"
tmux send-keys -t "$SESSION:web" "
  cd $REPO/frontend
  $HOME/flutter/bin/flutter run -d web-server \
    --web-port $PORT \
    --web-hostname 0.0.0.0
" Enter

echo ""
echo "VoxUI started in tmux session '$SESSION'"
echo "  livekit  → ws://localhost:7880"
echo "  token    → http://localhost:7882"
echo "  web      → http://localhost:$PORT"
echo ""
echo "Attach with: tmux attach -t $SESSION"
